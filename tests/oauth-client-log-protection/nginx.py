#!/usr/bin/env python3
"""Exercise the evaluated site fragment with nginx and a loopback responder.

This checks proxy logging and wire preservation, not application OAuth login or
the generated host configurations. Keep output outside the source checkout.
"""

import argparse
import hashlib
import http.client
import http.server
import json
from pathlib import Path
import socket
import subprocess
import threading
import time


def free_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--nginx", required=True)
    parser.add_argument("--fragment-values", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    run = args.output_dir.resolve()
    run.mkdir(exist_ok=False)
    raw_values = args.fragment_values.read_bytes()
    values = json.loads(raw_values)
    assert set(values) == {"httpConfig", "serverConfig", "referrerConfig"}
    sentinels = {
        key: "SYNTH_" + key.upper() + "_926b"
        for key in (
            "code", "state", "access_token", "refresh_token", "client_secret",
            "cookie", "authorization", "referer", "location", "set_cookie",
            "provider_body",
        )
    }
    requests = []

    class Upstream(http.server.BaseHTTPRequestHandler):
        def log_message(self, *unused):
            pass

        def do_GET(self):
            requests.append({"path": self.path, "headers": dict(self.headers)})
            status = (
                502 if self.path.startswith("/provider-error") else
                302 if self.path.startswith("/callback") else 200
            )
            self.send_response(status)
            self.send_header("Referrer-Policy", "unsafe-url")
            self.send_header("Location", "/continue?code=" + sentinels["location"])
            self.send_header("Set-Cookie", "session=" + sentinels["set_cookie"] + "; HttpOnly")
            body = (
                sentinels["provider_body"].encode() if status == 502
                else b"ordinary response"
            )
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    upstream = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Upstream)
    thread = threading.Thread(target=upstream.serve_forever, daemon=True)
    thread.start()
    port, redirect_port, unavailable_port = free_port(), free_port(), free_port()
    server_config = (values["serverConfig"] + values["referrerConfig"]).replace(
        "/var/log/nginx/oauth-clients.log", str(run / "access.log")
    )
    config = f"""pid {run}/nginx.pid;
error_log {run}/startup-error.log;
events {{ worker_connections 64; }}
http {{
  {values['httpConfig']}
  server {{
    listen 127.0.0.1:{port}; server_name client.test;
    {server_config}
    error_page 503 @maintenance;
    location / {{ proxy_pass http://127.0.0.1:{upstream.server_port}; }}
    location /unavailable {{ proxy_pass http://127.0.0.1:{unavailable_port}; }}
    location /maintenance {{ return 503; }}
    location @maintenance {{ return 503 "maintenance"; }}
  }}
  server {{
    listen 127.0.0.1:{redirect_port}; server_name client.test;
    {server_config}
    location / {{ return 301 https://$host$request_uri; }}
    location ^~ /.well-known/acme-challenge/ {{ return 200 "challenge"; }}
  }}
}}
"""
    config_path = run / "nginx.conf"
    config_path.write_text(config)
    common_args = ["-e", "stderr", "-c", str(config_path), "-p", str(run)]
    proc = None
    result = {
        "scope": "synthetic nginx fragment/wire/log check; not full installed stack or OAuth login",
        "nginx": args.nginx,
        "fragment_values_sha256": hashlib.sha256(raw_values).hexdigest(),
    }
    try:
        syntax = subprocess.run(
            [args.nginx, "-t", *common_args], capture_output=True, text=True, check=False
        )
        (run / "syntax.stdout").write_text(syntax.stdout)
        (run / "syntax.stderr").write_text(syntax.stderr)
        assert syntax.returncode == 0, syntax.stderr
        with (run / "nginx.stdout").open("w") as stdout, (run / "nginx.stderr").open("w") as stderr:
            proc = subprocess.Popen(
                [args.nginx, *common_args, "-g", "daemon off;"], stdout=stdout, stderr=stderr
            )
            deadline = time.monotonic() + 5
            while True:
                assert proc.poll() is None, "owned nginx failed at launch"
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                        break
                except OSError:
                    assert time.monotonic() < deadline, "owned nginx listener setup failed"
                    time.sleep(0.05)

            def request(target_port, path):
                conn = http.client.HTTPConnection("127.0.0.1", target_port, timeout=3)
                try:
                    conn.request("GET", path, headers=headers)
                    response = conn.getresponse()
                    status, body, response_headers = response.status, response.read(), response.getheaders()
                    assert [v for k, v in response_headers if k.lower() == "referrer-policy"] == ["strict-origin"]
                    return status, body, dict(response_headers)
                finally:
                    conn.close()

            query = "&".join(
                key + "=" + sentinels[key]
                for key in ("code", "state", "access_token", "refresh_token", "client_secret")
            )
            headers = {
                "Host": "client.test",
                "Cookie": "session=" + sentinels["cookie"],
                "Authorization": "Bearer " + sentinels["authorization"],
                "Referer": "https://client.test/callback?code=" + sentinels["referer"],
            }
            checks = []
            for path, expected in (
                ("/callback?" + query, 302), ("/provider-error?" + query, 502),
                ("/ordinary", 200), ("/unavailable?code=" + sentinels["code"], 502),
                ("/maintenance?state=" + sentinels["state"], 503),
            ):
                status, body, response_headers = request(port, path)
                assert status == expected, (path, status)
                if not path.startswith(("/unavailable", "/maintenance")):
                    record = requests[-1]
                    assert record["path"] == path
                    for key in ("Cookie", "Authorization", "Referer"):
                        assert record["headers"][key] == headers[key]
                    assert response_headers["Location"] == "/continue?code=" + sentinels["location"]
                    assert response_headers["Set-Cookie"] == "session=" + sentinels["set_cookie"] + "; HttpOnly"
                    if status == 502:
                        assert body == sentinels["provider_body"].encode()
                checks.append({"path": path.split("?")[0], "status": status})
            path = "/callback?" + query
            status, _, response_headers = request(redirect_port, path)
            assert status == 301 and response_headers["Location"] == "https://client.test" + path
            status, body, _ = request(redirect_port, "/.well-known/acme-challenge/test?code=" + sentinels["code"])
            assert status == 200 and body == b"challenge"
            result["response_checks"] = checks
    finally:
        if proc is not None and proc.poll() is None:
            quit_result = subprocess.run(
                [args.nginx, "-s", "quit", *common_args], capture_output=True, text=True, check=False
            )
            (run / "quit.stderr").write_text(quit_result.stderr)
            assert quit_result.returncode == 0
            proc.wait(timeout=5)
        upstream.shutdown()
        upstream.server_close()
        thread.join(timeout=2)

    logs = "".join(
        (run / name).read_text() if (run / name).exists() else ""
        for name in ("access.log", "startup-error.log", "nginx.stdout", "nginx.stderr")
    )
    assert all(value not in logs for value in sentinels.values()), "sentinel in actual nginx output"
    access = (run / "access.log").read_text()
    lines = access.splitlines()
    assert len(lines) == 7, lines
    assert '/ordinary HTTP/1.1" 200 ' in access
    assert '/provider-error HTTP/1.1" 502 ' in access
    assert '/unavailable HTTP/1.1" 502 ' in access
    assert all("?" not in line for line in lines)
    for used_port in (port, redirect_port):
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", used_port))
    assert proc.returncode == 0
    result.update({
        "result": "PASS", "actual_log_sentinels_absent": True,
        "request_and_response_values_preserved": True,
        "redirect_target_and_acme_precedence_preserved": True,
        "maintenance_log_and_header_inheritance": True,
        "benign_status_timing_diagnostics_retained": True,
        "safe_access_records": len(lines), "owned_process_and_ports_reconciled": True,
    })
    (run / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
