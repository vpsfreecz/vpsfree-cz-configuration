#!/usr/bin/env python3
"""Synchronous fixed-path authenticated blog package receiver."""
import argparse
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import json
import os
from pathlib import Path
import pwd
import re
import socket
import tempfile
import threading
import time

spec = importlib.util.spec_from_file_location('blog_release', Path(__file__).with_name('blog-static-release.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
PATH = '/_deploy/blog'
MAX_BYTES = release.MAX_BYTES
BODY_SECONDS = 180


def signing_message(run_number, body_digest):
    return f'blog-upload-v1\nPOST\n{PATH}\n{run_number}\n{body_digest}\n'.encode('ascii')


class UploadError(ValueError):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


def authenticate(method, path, headers, key):
    if method != 'POST' or path != PATH:
        raise UploadError(404, 'Unknown upload endpoint')
    def single(name):
        values = headers.get_all(name, [])
        if len(values) != 1:
            raise UploadError(400, 'Missing or duplicate upload header')
        return values[0]
    if headers.get_all('Transfer-Encoding') or headers.get_all('Content-Encoding'):
        raise UploadError(400, 'Encoded transfer unsupported')
    if single('Content-Type').lower() != 'application/zip':
        raise UploadError(415, 'Expected application/zip')
    length = single('Content-Length')
    number = single('X-Blog-Run-Number')
    body_digest = single('X-Blog-Body-SHA256')
    signature = single('X-Blog-Signature')
    if not re.fullmatch(r'[1-9][0-9]{0,18}', length) or int(length) > MAX_BYTES:
        raise UploadError(413, 'Upload exceeds fixed size limit')
    if not re.fullmatch(r'[1-9][0-9]{0,18}', number) or int(number) >= 2 ** 63:
        raise UploadError(400, 'Invalid workflow run number')
    if not re.fullmatch(r'[0-9a-f]{64}', body_digest) or not re.fullmatch(r'sha256=[0-9a-f]{64}', signature):
        raise UploadError(401, 'Invalid upload authentication')
    expected = 'sha256=' + hmac.new(key, signing_message(number, body_digest), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(signature, expected):
        raise UploadError(401, 'Invalid upload authentication')
    return int(length), int(number), body_digest


class Server(ThreadingHTTPServer):
    daemon_threads = True
    # No background queue of packages. One bounded body/validation/commit at once.
    request_queue_size = 8

    def __init__(self, address, key, publication):
        self.key = key
        self.publication = publication
        self.busy = threading.Lock()
        super().__init__(address, Handler)

    def get_request(self):
        connection, address = super().get_request()
        connection.settimeout(10)
        return connection, address

    def handle_error(self, request, client_address):
        # Never log request headers/body or exceptions that may contain payloads.
        pass


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, status, result):
        self.close_connection = True
        body = release.encode(result)
        try:
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError, socket.timeout):
            # A committed release remains committed after a lost reply.
            pass

    def do_POST(self):
        try:
            length, number, expected = authenticate('POST', self.path, self.headers, self.server.key)
        except UploadError as error:
            return self.reply(error.status, {'error': str(error)})
        if not self.server.busy.acquire(blocking=False):
            return self.reply(503, {'error': 'Upload busy; retry identical bytes'})
        try:
            self.server.publication.allowed()
            with tempfile.TemporaryFile() as body:
                remaining, hashed = length, hashlib.sha256()
                deadline = time.monotonic() + BODY_SECONDS
                while remaining:
                    available = deadline - time.monotonic()
                    if available <= 0:
                        raise UploadError(408, 'Upload body deadline exceeded')
                    self.connection.settimeout(available)
                    chunk = self.rfile.read(min(1024 * 1024, remaining))
                    if not chunk:
                        raise UploadError(400, 'Incomplete upload body')
                    hashed.update(chunk)
                    body.write(chunk)
                    remaining -= len(chunk)
                if not hmac.compare_digest(hashed.hexdigest(), expected):
                    raise UploadError(400, 'Upload body digest mismatch')
                body.seek(0)
                result = self.server.publication.upload(body, number, expected)
            # No success before the transaction's receipt and directory barriers.
            self.reply(200, result)
        except UploadError as error:
            self.reply(error.status, {'error': str(error)})
        except release.Paused:
            self.reply(503, {'error': 'Publication paused; operator resume required'})
        except release.Rejected:
            self.reply(409, {'error': 'Upload rejected; inspect ordering, package or selected policy'})
        except (socket.timeout, TimeoutError):
            self.reply(408, {'error': 'Upload body deadline exceeded'})
        except (ValueError, KeyError, TypeError, release.zipfile.BadZipFile, release.tarfile.TarError):
            self.reply(400, {'error': 'Invalid release package'})
        except OSError:
            self.reply(500, {'error': 'Publication incomplete; retry identical bytes or inspect root status'})
        finally:
            self.server.busy.release()

    def do_GET(self):
        self.reply(404, {'error': 'Unknown upload endpoint'})

    do_PUT = do_GET
    do_DELETE = do_GET


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--secret-file', type=Path, required=True)
    options = parser.parse_args()
    release.require(os.geteuid() != 0 and os.geteuid() == pwd.getpwnam('blog-release').pw_uid,
                    'Upload service requires fixed blog-release identity')
    key = options.secret_file.read_bytes()
    release.require(32 <= len(key) <= 4096, 'Deployment key must contain 32 to 4096 exact bytes')
    publication = release.Publication()
    publication.policy()
    Server(('127.0.0.1', 8091), key, publication).serve_forever()


if __name__ == '__main__':
    main()
