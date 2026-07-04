#!/usr/bin/env python3
import argparse
import json
import os
import sys
import time
import uuid
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


DEFAULT_BASE_URL = "https://api.deepseek.com"
DEFAULT_STATE_DIR = "/var/lib/codex-deepseek-responses-proxy"
FALLBACK_REASONING_CONTENT = (
    "Reasoning content unavailable; inserted by Codex DeepSeek proxy for chat history continuity."
)
REAL_MODEL_ALIASES = {
    "deepseek-v4": ("deepseek-v4-flash", "enabled"),
    "deepseek-v4-think": ("deepseek-v4-flash", "enabled"),
    "deepseek-v4-nothink": ("deepseek-v4-flash", "disabled"),
    "deepseek-v4-flash-think": ("deepseek-v4-flash", "enabled"),
    "deepseek-v4-flash-nothink": ("deepseek-v4-flash", "disabled"),
    "deepseek-v4-pro-think": ("deepseek-v4-pro", "enabled"),
    "deepseek-v4-pro-nothink": ("deepseek-v4-pro", "disabled"),
}

# DeepSeek requires reasoning_content to be replayed after thinking-mode tool calls.
CALL_REASONING = {}
CALL_REASONING_LOADED = False
MAX_REASONING_ENTRIES = int(os.environ.get("DEEPSEEK_PROXY_MAX_REASONING_ENTRIES", "2000"))


class DeepSeekRequestError(RuntimeError):
    def __init__(self, status, body):
        super().__init__(f"DeepSeek HTTP {status}: {body}")
        self.status = status
        self.body = body


def call_reasoning_path():
    return os.environ.get(
        "DEEPSEEK_CALL_REASONING_FILE",
        os.path.join(
            os.environ.get("DEEPSEEK_PROXY_STATE_DIR", DEFAULT_STATE_DIR),
            "deepseek-call-reasoning.json",
        ),
    )


def load_call_reasoning():
    global CALL_REASONING_LOADED
    if CALL_REASONING_LOADED:
        return
    CALL_REASONING_LOADED = True
    try:
        with open(call_reasoning_path(), "r", encoding="utf-8") as handle:
            stored = json.load(handle)
    except FileNotFoundError:
        return
    except Exception as exc:
        sys.stderr.write(f"failed to load DeepSeek reasoning state: {exc}\n")
        return

    if not isinstance(stored, dict):
        return
    for call_id, reasoning in stored.items():
        if isinstance(call_id, str) and isinstance(reasoning, str):
            CALL_REASONING[call_id] = reasoning


def save_call_reasoning():
    path = call_reasoning_path()
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    tmp_path = path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as handle:
        json.dump(CALL_REASONING, handle, ensure_ascii=False, separators=(",", ":"))
        handle.write("\n")
    os.chmod(tmp_path, 0o600)
    os.replace(tmp_path, path)


def remember_reasoning(call_id, reasoning):
    if not call_id or not reasoning:
        return
    load_call_reasoning()
    CALL_REASONING.pop(call_id, None)
    CALL_REASONING[call_id] = reasoning
    while len(CALL_REASONING) > MAX_REASONING_ENTRIES:
        CALL_REASONING.pop(next(iter(CALL_REASONING)))
    try:
        save_call_reasoning()
    except Exception as exc:
        sys.stderr.write(f"failed to save DeepSeek reasoning state: {exc}\n")


def now():
    return int(time.time())


def json_dumps(value):
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False)


def response_id():
    return "resp_" + uuid.uuid4().hex


def item_id(prefix):
    return prefix + "_" + uuid.uuid4().hex


def text_from_content(content):
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return str(content)

    parts = []
    for part in content:
        if isinstance(part, str):
            parts.append(part)
            continue
        if not isinstance(part, dict):
            parts.append(str(part))
            continue
        part_type = part.get("type")
        if part_type in ("input_text", "output_text", "text"):
            parts.append(part.get("text") or "")
        elif "text" in part:
            parts.append(part.get("text") or "")
        elif part_type in ("input_image", "image"):
            parts.append("[image input omitted: DeepSeek chat proxy is text-only]")
    return "\n".join(part for part in parts if part)


def normalize_role(role):
    if role in ("developer", "system"):
        return "system"
    if role in ("assistant", "tool", "user"):
        return role
    return "user"


def convert_message_item(item):
    role = normalize_role(item.get("role"))
    return {
        "role": role,
        "content": text_from_content(item.get("content")),
    }


def convert_function_call_group(items, content=""):
    load_call_reasoning()
    tool_calls = []
    reasoning = None
    for item in items:
        call_id = item.get("call_id") or item.get("id") or ("call_" + uuid.uuid4().hex)
        if reasoning is None:
            reasoning = (
                CALL_REASONING.get(item.get("call_id") or "")
                or CALL_REASONING.get(item.get("id") or "")
                or CALL_REASONING.get(call_id)
            )
        tool_calls.append({
            "id": call_id,
            "type": "function",
            "function": {
                "name": item.get("name") or "",
                "arguments": item.get("arguments") or "{}",
            },
        })

    message = {
        "role": "assistant",
        "content": content or "",
        "tool_calls": tool_calls,
    }
    message["reasoning_content"] = reasoning or FALLBACK_REASONING_CONTENT
    return message


def tool_call_ids(message):
    return [
        call.get("id")
        for call in message.get("tool_calls", [])
        if call.get("id")
    ]


def placeholder_tool_result_message(call_id):
    return {
        "role": "tool",
        "tool_call_id": call_id,
        "content": "Tool call result was not present in the Codex history.",
    }


def complete_pending_tool_calls(messages, pending_tool_call_ids):
    for call_id in list(pending_tool_call_ids):
        messages.append(placeholder_tool_result_message(call_id))
    pending_tool_call_ids.clear()


def ensure_assistant_reasoning(messages):
    last_reasoning = None
    for message in messages:
        if message.get("role") != "assistant":
            continue
        reasoning = message.get("reasoning_content")
        if reasoning:
            last_reasoning = reasoning
            continue
        message["reasoning_content"] = last_reasoning or FALLBACK_REASONING_CONTENT


def convert_input_items(input_items):
    messages = []
    index = 0
    pending_tool_call_ids = []
    while index < len(input_items):
        item = input_items[index]
        item_type = item.get("type")

        if item_type == "message":
            complete_pending_tool_calls(messages, pending_tool_call_ids)
            messages.append(convert_message_item(item))
            index += 1
            continue

        if item_type == "function_call":
            complete_pending_tool_calls(messages, pending_tool_call_ids)
            group = []
            while index < len(input_items) and input_items[index].get("type") == "function_call":
                group.append(input_items[index])
                index += 1
            assistant_content = ""
            if messages and messages[-1].get("role") == "assistant" and "tool_calls" not in messages[-1]:
                assistant_content = messages.pop().get("content") or ""
            message = convert_function_call_group(group, assistant_content)
            pending_tool_call_ids = tool_call_ids(message)
            messages.append(message)
            continue

        if item_type == "function_call_output":
            call_id = item.get("call_id") or ""
            if call_id not in pending_tool_call_ids:
                index += 1
                continue
            messages.append({
                "role": "tool",
                "tool_call_id": call_id,
                "content": text_from_content(item.get("output")),
            })
            if call_id in pending_tool_call_ids:
                pending_tool_call_ids.remove(call_id)
            index += 1
            continue

        index += 1

    complete_pending_tool_calls(messages, pending_tool_call_ids)
    return messages


def convert_tools(tools):
    converted = []
    for tool in tools or []:
        if not isinstance(tool, dict) or tool.get("type") != "function":
            continue
        converted.append({
            "type": "function",
            "function": {
                "name": tool.get("name"),
                "description": tool.get("description") or "",
                "parameters": tool.get("parameters") or {"type": "object", "properties": {}},
            },
        })
    return converted


def resolve_model(model):
    if model in REAL_MODEL_ALIASES:
        return REAL_MODEL_ALIASES[model]
    if model.endswith("-nothink"):
        return model[:-8], "disabled"
    return model, "enabled"


def resolve_effort(request):
    reasoning = request.get("reasoning")
    effort = None
    if isinstance(reasoning, dict):
        effort = reasoning.get("effort")
    effort = effort or os.environ.get("DEEPSEEK_REASONING_EFFORT") or "high"
    if effort == "xhigh":
        return "max"
    if effort in ("low", "medium"):
        return "high"
    if effort in ("high", "max"):
        return effort
    return "high"


def build_chat_payload(request):
    model, thinking = resolve_model(request.get("model") or "deepseek-v4-flash")
    messages = []

    instructions = request.get("instructions")
    if instructions:
        messages.append({"role": "system", "content": instructions})

    messages.extend(convert_input_items(request.get("input") or []))
    if not messages:
        messages.append({"role": "user", "content": ""})
    if thinking == "enabled":
        ensure_assistant_reasoning(messages)
    else:
        for message in messages:
            message.pop("reasoning_content", None)

    payload = {
        "model": model,
        "messages": messages,
        "stream": True,
        "stream_options": {"include_usage": True},
        "thinking": {"type": thinking},
    }

    tools = convert_tools(request.get("tools"))
    if tools:
        payload["tools"] = tools
        payload["tool_choice"] = "auto"
        if "parallel_tool_calls" in request:
            payload["parallel_tool_calls"] = bool(request.get("parallel_tool_calls"))

    if thinking == "enabled":
        payload["reasoning_effort"] = resolve_effort(request)

    if "max_output_tokens" in request:
        payload["max_tokens"] = request["max_output_tokens"]

    return payload, thinking


def iter_sse_lines(response):
    data_lines = []
    for raw_line in response:
        line = raw_line.decode("utf-8", errors="replace").rstrip("\r\n")
        if not line:
            if data_lines:
                yield "\n".join(data_lines)
                data_lines = []
            continue
        if line.startswith("data:"):
            data_lines.append(line[5:].lstrip())
    if data_lines:
        yield "\n".join(data_lines)


class SseWriter:
    def __init__(self, handler):
        self.handler = handler

    def event(self, event_type, payload):
        self.handler.wfile.write(f"event: {event_type}\n".encode())
        self.handler.wfile.write(("data: " + json_dumps(payload) + "\n\n").encode("utf-8"))
        self.handler.wfile.flush()

    def done(self):
        self.handler.wfile.write(b"data: [DONE]\n\n")
        self.handler.wfile.flush()


class ResponseEmitter:
    def __init__(self, writer, model):
        self.writer = writer
        self.model = model
        self.response_id = response_id()
        self.output = []
        self.message_item_id = None
        self.message_text = ""
        self.message_open = False

    def start(self):
        self.writer.event("response.created", {
            "type": "response.created",
            "response": {
                "id": self.response_id,
                "object": "response",
                "created_at": now(),
                "status": "in_progress",
                "model": self.model,
                "output": [],
            },
        })

    def ensure_message(self):
        if self.message_open:
            return
        self.message_item_id = item_id("msg")
        self.message_open = True
        self.writer.event("response.output_item.added", {
            "type": "response.output_item.added",
            "response_id": self.response_id,
            "output_index": len(self.output),
            "item": {
                "id": self.message_item_id,
                "type": "message",
                "status": "in_progress",
                "role": "assistant",
                "content": [],
            },
        })
        self.writer.event("response.content_part.added", {
            "type": "response.content_part.added",
            "response_id": self.response_id,
            "item_id": self.message_item_id,
            "output_index": len(self.output),
            "content_index": 0,
            "part": {"type": "output_text", "text": "", "annotations": []},
        })

    def text_delta(self, delta):
        if not delta:
            return
        self.ensure_message()
        self.message_text += delta
        self.writer.event("response.output_text.delta", {
            "type": "response.output_text.delta",
            "response_id": self.response_id,
            "item_id": self.message_item_id,
            "output_index": len(self.output),
            "content_index": 0,
            "delta": delta,
        })

    def finish_message(self):
        if not self.message_open:
            return
        output_index = len(self.output)
        part = {"type": "output_text", "text": self.message_text, "annotations": []}
        self.writer.event("response.output_text.done", {
            "type": "response.output_text.done",
            "response_id": self.response_id,
            "item_id": self.message_item_id,
            "output_index": output_index,
            "content_index": 0,
            "text": self.message_text,
        })
        self.writer.event("response.content_part.done", {
            "type": "response.content_part.done",
            "response_id": self.response_id,
            "item_id": self.message_item_id,
            "output_index": output_index,
            "content_index": 0,
            "part": part,
        })
        item = {
            "id": self.message_item_id,
            "type": "message",
            "status": "completed",
            "role": "assistant",
            "content": [part],
        }
        self.writer.event("response.output_item.done", {
            "type": "response.output_item.done",
            "response_id": self.response_id,
            "output_index": output_index,
            "item": item,
        })
        self.output.append(item)
        self.message_open = False

    def function_call(self, name, arguments, call_id, reasoning):
        output_index = len(self.output)
        call_item_id = item_id("fc")
        remember_reasoning(call_id, reasoning)
        remember_reasoning(call_item_id, reasoning)
        item = {
            "id": call_item_id,
            "type": "function_call",
            "status": "completed",
            "call_id": call_id,
            "name": name,
            "arguments": arguments or "{}",
        }
        self.writer.event("response.output_item.added", {
            "type": "response.output_item.added",
            "response_id": self.response_id,
            "output_index": output_index,
            "item": {**item, "status": "in_progress", "arguments": ""},
        })
        self.writer.event("response.function_call_arguments.delta", {
            "type": "response.function_call_arguments.delta",
            "response_id": self.response_id,
            "item_id": call_item_id,
            "output_index": output_index,
            "delta": arguments or "{}",
        })
        self.writer.event("response.function_call_arguments.done", {
            "type": "response.function_call_arguments.done",
            "response_id": self.response_id,
            "item_id": call_item_id,
            "output_index": output_index,
            "arguments": arguments or "{}",
        })
        self.writer.event("response.output_item.done", {
            "type": "response.output_item.done",
            "response_id": self.response_id,
            "output_index": output_index,
            "item": item,
        })
        self.output.append(item)

    def complete(self, usage=None):
        self.finish_message()
        self.writer.event("response.completed", {
            "type": "response.completed",
            "response": {
                "id": self.response_id,
                "object": "response",
                "created_at": now(),
                "status": "completed",
                "model": self.model,
                "output": self.output,
                "usage": usage or {
                    "input_tokens": 0,
                    "output_tokens": 0,
                    "total_tokens": 0,
                },
            },
        })
        self.writer.done()


def accumulate_tool_calls(existing, delta_tool_calls):
    for tool_call in delta_tool_calls or []:
        index = tool_call.get("index", 0)
        current = existing.setdefault(index, {
            "id": None,
            "name": "",
            "arguments": "",
        })
        if tool_call.get("id"):
            current["id"] = tool_call["id"]
        function = tool_call.get("function") or {}
        if function.get("name"):
            current["name"] += function["name"]
        if function.get("arguments"):
            current["arguments"] += function["arguments"]


def deepseek_request(payload):
    api_key = deepseek_api_key()
    if not api_key:
        raise RuntimeError("DEEPSEEK_API_KEY or DEEPSEEK_API_KEY_FILE is not set")

    base_url = os.environ.get("DEEPSEEK_BASE_URL", DEFAULT_BASE_URL).rstrip("/")
    request = urllib.request.Request(
        base_url + "/chat/completions",
        data=json_dumps(payload).encode("utf-8"),
        headers={
            "Authorization": "Bearer " + api_key,
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
        },
        method="POST",
    )
    try:
        return urllib.request.urlopen(request, timeout=900)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise DeepSeekRequestError(exc.code, body) from exc


def deepseek_api_key():
    if os.environ.get("DEEPSEEK_API_KEY"):
        return os.environ["DEEPSEEK_API_KEY"].strip()

    path = os.environ.get("DEEPSEEK_API_KEY_FILE")
    if not path:
        return None

    with open(path, "r", encoding="utf-8") as handle:
        return handle.read().strip()


def payload_summary(payload):
    if not payload:
        return "unavailable"
    summary = []
    for message in payload.get("messages") or []:
        entry = message.get("role") or "unknown"
        if "tool_calls" in message:
            entry += f"/tool_calls={len(message.get('tool_calls') or [])}"
        if "tool_call_id" in message:
            entry += "/tool_result"
        if "reasoning_content" in message:
            entry += f"/reasoning_len={len(message.get('reasoning_content') or '')}"
        summary.append(entry)
    return ",".join(summary)


class Handler(BaseHTTPRequestHandler):
    server_version = "codex-deepseek-responses-proxy/1.0"

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"ok": True})
            return
        self.send_json(404, {"error": "not_found"})

    def do_POST(self):
        if self.path not in ("/responses", "/v1/responses"):
            self.send_json(404, {"error": "not_found"})
            return

        if not self.authorized():
            self.send_json(401, {"error": "unauthorized"})
            return

        payload = None
        try:
            length = int(self.headers.get("content-length") or "0")
            request = json.loads(self.rfile.read(length))
            payload, thinking = build_chat_payload(request)
            upstream = deepseek_request(payload)
        except DeepSeekRequestError as exc:
            sys.stderr.write(
                "deepseek upstream rejected request: "
                f"status={exc.status} body={exc.body} messages={payload_summary(payload)}\n"
            )
            status = exc.status if 400 <= exc.status < 500 else 502
            self.send_json(status, {"error": str(exc), "upstream_status": exc.status})
            return
        except Exception as exc:
            self.send_json(502, {"error": str(exc)})
            return

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()

        writer = SseWriter(self)
        emitter = ResponseEmitter(writer, payload["model"])
        tool_calls = {}
        reasoning = ""
        usage = None
        emitter.start()

        try:
            for data_line in iter_sse_lines(upstream):
                if data_line == "[DONE]":
                    break
                chunk = json.loads(data_line)
                if chunk.get("usage"):
                    usage = normalize_usage(chunk["usage"])

                choices = chunk.get("choices") or []
                if not choices:
                    continue
                delta = choices[0].get("delta") or {}
                if delta.get("reasoning_content") and thinking == "enabled":
                    reasoning += delta["reasoning_content"]
                if delta.get("content"):
                    emitter.text_delta(delta["content"])
                accumulate_tool_calls(tool_calls, delta.get("tool_calls"))

            for index in sorted(tool_calls):
                tool_call = tool_calls[index]
                call_id = tool_call["id"] or ("call_" + uuid.uuid4().hex)
                emitter.function_call(
                    tool_call["name"],
                    tool_call["arguments"],
                    call_id,
                    reasoning,
                )

            if not emitter.output and not tool_calls:
                emitter.ensure_message()
            emitter.complete(usage)
        except Exception as exc:
            sys.stderr.write(f"stream conversion failed: {exc}\n")

    def authorized(self):
        expected = os.environ.get("DEEPSEEK_PROXY_API_KEY")
        if not expected:
            return True
        return self.headers.get("authorization") == "Bearer " + expected

    def send_json(self, status, body):
        data = (json_dumps(body) + "\n").encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def normalize_usage(usage):
    input_tokens = usage.get("prompt_tokens") or usage.get("input_tokens") or 0
    output_tokens = usage.get("completion_tokens") or usage.get("output_tokens") or 0
    total_tokens = usage.get("total_tokens") or input_tokens + output_tokens
    return {
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "total_tokens": total_tokens,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=4141)
    args = parser.parse_args()
    load_call_reasoning()

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    sys.stderr.write(f"listening on http://{args.host}:{args.port}\n")
    server.serve_forever()


if __name__ == "__main__":
    main()
