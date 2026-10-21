"""Exercise the production-generated policy against deliberately permissive stubs.

All credentials are synthetic and stay in process memory or disposable files.
The HTTP fixture checks the nginx boundary; public TLS remains a deployment check.
"""

import argparse
import base64
import concurrent.futures
import http.client
import http.server
import json
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time

HOSTS = ["mon1.prg.vpsfree.cz", "mon2.prg.vpsfree.cz"]
USERNAME = "codex-aitherdev"
PASSWORD = "synthetic-query-fixture-password"
HUMAN = "synthetic-human"
HUMAN_PASSWORD = "synthetic-human-password"
POST_PATHS = ["query", "query_range", "series", "labels"]
GET_PATHS = [
    "label/__name__/values", "metadata", "targets", "targets/metadata",
    "rules", "alerts", "status/buildinfo", "status/runtimeinfo",
]
RECEIVED = []
RECEIVED_LOCK = threading.Lock()
SLOW = threading.Event()
ACTIVE = 0
ACTIVE_CONDITION = threading.Condition()


class Stub(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        global ACTIVE
        length = int(self.headers.get("Content-Length", "0"))
        record = {
            "server": self.server.server_port, "method": self.command,
            "path": self.path, "body": self.rfile.read(length).decode(),
            "authorization": self.headers.get("Authorization"),
        }
        with RECEIVED_LOCK:
            RECEIVED.append(record)
        if "slow=1" in self.path:
            with ACTIVE_CONDITION:
                ACTIVE += 1
                ACTIVE_CONDITION.notify_all()
            SLOW.wait(15)
            with ACTIVE_CONDITION:
                ACTIVE -= 1
        body = json.dumps(record).encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    do_POST = do_PUT = do_DELETE = do_PATCH = do_HEAD = do_OPTIONS = do_GET

    def log_message(self, *_):
        pass


def authorization(user=USERNAME, password=PASSWORD):
    return "Basic " + base64.b64encode(f"{user}:{password}".encode()).decode()


def request(host, path, method="GET", body=None, auth=True, connection=None):
    own = connection is None
    conn = connection or http.client.HTTPConnection("127.0.0.1", 18080, timeout=20)
    headers = {"Host": host}
    if auth:
        headers["Authorization"] = authorization() if auth is True else auth
    if body is not None:
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    conn.request(method, path, body=body, headers=headers)
    response = conn.getresponse()
    result = (response.status, response.read())
    if own:
        conn.close()
    return result


def spaced_request(*args, **kwargs):
    # Drain the shared token bucket between policy probes.
    time.sleep(0.52)
    return request(*args, **kwargs)


def denied(host, path, method="GET", auth=True, statuses=(400, 401, 403, 404, 405)):
    with RECEIVED_LOCK:
        before = len(RECEIVED)
    status, _ = spaced_request(host, path, method=method, auth=auth)
    assert status in statuses, (host, path, method, status)
    with RECEIVED_LOCK:
        assert len(RECEIVED) == before, ("denied request reached upstream", path)


def htpasswd(path, user, password):
    result = subprocess.run(
        ["htpasswd", "-niBC", "8", user], input=password + "\n",
        text=True, capture_output=True, check=True,
    )
    assert result.stdout.startswith(user + ":$2")
    replacement = path.with_suffix(".new")
    replacement.write_text(result.stdout)
    replacement.chmod(0o600)
    replacement.replace(path)


def http2_rotation(auth_file):
    import h2.config
    import h2.connection
    import h2.events

    sock = socket.create_connection(("127.0.0.1", 18080), timeout=10)
    conn = h2.connection.H2Connection(config=h2.config.H2Configuration(header_encoding="utf-8"))
    conn.initiate_connection()
    sock.sendall(conn.data_to_send())

    responses = {}
    ended = set()

    def send(auth, path="/codex/api/v1/query?query=up"):
        stream = conn.get_next_available_stream_id()
        conn.send_headers(stream, [
            (":method", "GET"), (":scheme", "http"), (":authority", HOSTS[1]),
            (":path", path), ("authorization", auth),
        ], end_stream=True)
        sock.sendall(conn.data_to_send())
        return stream

    def finish(stream):
        while stream not in ended:
            data = sock.recv(65535)
            if not data:
                raise RuntimeError(f"HTTP/2 connection closed before stream {stream} completed")
            for event in conn.receive_data(data):
                if isinstance(event, h2.events.ConnectionTerminated):
                    raise RuntimeError(f"HTTP/2 GOAWAY before stream completion: {event.error_code}")
                if isinstance(event, h2.events.StreamReset):
                    raise RuntimeError(f"HTTP/2 stream {event.stream_id} reset: {event.error_code}")
                if isinstance(event, h2.events.ResponseReceived):
                    responses[event.stream_id] = int(dict(event.headers)[":status"])
                if isinstance(event, h2.events.DataReceived):
                    conn.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
                if isinstance(event, h2.events.StreamEnded):
                    ended.add(event.stream_id)
            sock.sendall(conn.data_to_send())
        return responses[stream]

    def get(auth):
        time.sleep(0.52)
        return finish(send(auth))

    # HTTP/2 streams share the same request and concurrency budgets.
    time.sleep(3.1)
    streams = [send(authorization()) for _ in range(12)]
    assert 429 in [finish(stream) for stream in streams]
    time.sleep(3.1)
    SLOW.clear()
    slow_streams = []
    try:
        for i in range(4):
            slow_streams.append(send(authorization(), "/codex/api/v1/query?slow=1"))
            with ACTIVE_CONDITION:
                assert ACTIVE_CONDITION.wait_for(lambda: ACTIVE == i + 1, timeout=5)
            time.sleep(0.52)
        assert finish(send(authorization())) == 429
    finally:
        SLOW.set()
    assert all(finish(stream) == 200 for stream in slow_streams)

    assert get(authorization()) == 200
    htpasswd(auth_file, USERNAME, "synthetic-rotated-password")
    assert get(authorization()) == 401
    assert get(authorization(password="synthetic-rotated-password")) == 200
    replacement = auth_file.with_suffix(".empty")
    replacement.write_text("")
    replacement.replace(auth_file)
    assert get(authorization(password="synthetic-rotated-password")) == 401
    sock.close()


def exercise(auth_file):
    for index, host in enumerate(HOSTS):
        for endpoint in POST_PATHS + GET_PATHS:
            status, raw = spaced_request(host, "/codex/api/v1/" + endpoint + "?query=up&timeout=20s")
            assert status == 200, (endpoint, status)
            record = json.loads(raw)
            assert record["path"] == "/api/v1/" + endpoint + "?query=up&timeout=20s"
            assert record["server"] == 18090 + index
            assert record["authorization"] is None
        for endpoint in POST_PATHS:
            body = "query=sum%28up%29&match%5B%5D=up&timeout=20s"
            status, raw = spaced_request(host, "/codex/api/v1/" + endpoint, method="POST", body=body)
            record = json.loads(raw)
            assert status == 200 and record["method"] == "POST" and record["body"] == body
            assert record["authorization"] is None
        for path in [
            "/codex", "/codex/", "/codex/api/v1/query/", "/codex/api/v1/admin/tsdb/delete_series",
            "/codex/-/reload", "/codex/-/quit", "/codex/federate", "/codex/metrics",
            "/codex/api/v1/read", "/codex/api/v1/write", "/codex/api/v1/status/config",
            "/codex/api/v1/status/flags", "/codex/debug/pprof/", "/codex/graph",
            "/codex/api/v1/label/a/b/values", "/codex/api/v1/label/9invalid/values",
            "/codex/api/v1/%71uery", "/codex//api/v1/query", "/codex/api/v1/./query",
            "/codex/api/v1/label/a%2fb/values", "/codex/api/v1/label/%252e%252e/values",
            "/codex/api/v1/query%2f..%2fadmin/tsdb/delete_series",
            "/codex/../api/v1/admin/tsdb/delete_series",
        ]:
            denied(host, path)
        for method in ["PUT", "DELETE", "PATCH", "OPTIONS"]:
            denied(host, "/codex/api/v1/query", method=method)
        for endpoint in GET_PATHS:
            denied(host, "/codex/api/v1/" + endpoint, method="POST")
        denied(host, "/codex/api/v1/query", auth=False)
        denied(host, "/codex/api/v1/query", auth=authorization(password="wrong"))
        denied(host, "/codex/api/v1/query", auth=authorization(HUMAN, HUMAN_PASSWORD))
        denied(host, "/api/v1/query")
        denied(host, "/")
        status, _ = spaced_request(host, "/api/v1/query", auth=authorization(HUMAN, HUMAN_PASSWORD))
        assert status == 200
        status, _ = spaced_request(host, "/", auth=authorization(HUMAN, HUMAN_PASSWORD))
        assert status == 200
        denied(host, "/codex/api/v1/query", method="HEAD", auth=False)
        status, _ = spaced_request(host, "/codex/api/v1/query", method="HEAD")
        assert status == 200
        before = len(RECEIVED)
        status, _ = spaced_request(host, "/codex/api/v1/query", method="POST", body="x" * 65537)
        assert status == 413 and len(RECEIVED) == before

    # The quota spans both vhosts and credentials, including missing credentials.
    time.sleep(3.1)
    statuses = [request(HOSTS[i % 2], "/codex/api/v1/query", auth=False)[0] for i in range(12)]
    assert statuses.count(401) <= 6 and 429 in statuses, statuses

    # Hold four upstream requests across both hosts; human routes stay independent.
    time.sleep(3.1)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = []
        for i in range(4):
            futures.append(pool.submit(request, HOSTS[i % 2], "/codex/api/v1/query?slow=1"))
            with ACTIVE_CONDITION:
                assert ACTIVE_CONDITION.wait_for(lambda: ACTIVE == i + 1, timeout=5)
            time.sleep(0.52)
        assert request(HOSTS[1], "/codex/api/v1/query")[0] == 429
        assert request(HOSTS[1], "/api/v1/query", auth=authorization(HUMAN, HUMAN_PASSWORD))[0] == 200
        SLOW.set()
        assert all(f.result()[0] == 200 for f in futures)

    # Existing HTTP/1.1 connections reauthenticate every request after revocation.
    conn = http.client.HTTPConnection("127.0.0.1", 18080, timeout=10)
    assert spaced_request(HOSTS[0], "/codex/api/v1/query", connection=conn)[0] == 200
    htpasswd(auth_file, USERNAME, "synthetic-rotated-password")
    assert spaced_request(HOSTS[0], "/codex/api/v1/query", connection=conn)[0] == 401
    conn.close()
    htpasswd(auth_file, USERNAME, PASSWORD)
    http2_rotation(auth_file)
    auth_file.unlink()
    # Native nginx maps an absent password file (ENOENT) to 403, not 500.
    denied(HOSTS[0], "/codex/api/v1/query", statuses=(403,))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--syntax", action="store_true")
    parser.add_argument("config", type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="prometheus-query-test-") as directory:
        root = Path(directory)
        auth_file = root / "dedicated.htpasswd"
        human_file = root / "human.htpasswd"
        config = args.config.read_text()
        # Only fixture paths change; the production-generated locations are intact.
        config = config.replace("/run/nginx/nginx.pid", str(root / "nginx.pid"))
        config = config.replace("/var/log/nginx/access.log", str(root / "access.log"))
        config = config.replace("/var/lib/nginx-auth/prometheus-codex.htpasswd", str(auth_file))
        config = config.replace("/private/nginx/mon.htpasswd", str(human_file))
        config_path = root / "nginx.conf"
        config_path.write_text(config)
        subprocess.run(["nginx", "-t", "-e", "stderr", "-p", directory + "/", "-c", str(config_path)], check=True)
        if args.syntax:
            return
        htpasswd(auth_file, USERNAME, PASSWORD)
        htpasswd(human_file, HUMAN, HUMAN_PASSWORD)
        servers = [http.server.ThreadingHTTPServer(("127.0.0.1", port), Stub) for port in [18090, 18091]]
        for server in servers:
            threading.Thread(target=server.serve_forever, daemon=True).start()
        with (root / "stderr.log").open("w") as stderr:
            process = subprocess.Popen(["nginx", "-e", "stderr", "-p", directory + "/", "-c", str(config_path)], stderr=stderr)
            try:
                for _ in range(100):
                    try:
                        with socket.create_connection(("127.0.0.1", 18080), timeout=0.1):
                            break
                    except OSError:
                        if process.poll() is not None:
                            raise RuntimeError("nginx exited before listening")
                        time.sleep(0.02)
                exercise(auth_file)
            finally:
                SLOW.set()
                process.terminate()
                process.wait(timeout=10)
                for server in servers:
                    server.shutdown()
        logs = (root / "stderr.log").read_text() + (root / "access.log").read_text()
        for secret in [PASSWORD, HUMAN_PASSWORD, "synthetic-rotated-password", authorization()]:
            assert secret not in logs
        print("Prometheus query boundary, authentication, limits and rotation passed")


if __name__ == "__main__":
    main()
