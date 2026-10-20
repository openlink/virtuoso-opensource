#!/usr/bin/env python3
#
#  onnx_embedding_mock.py
#
#  OpenAI-compatible embedding endpoint used by tvvec_http_provider.sql.  Listens
#  only on loopback.  Besides the happy-path embedding endpoint it serves fault
#  endpoints so the provider-hardening tests (prompt 11) can exercise redirect,
#  retry/backoff and terminal-error handling, plus a GET /stats endpoint that
#  reports per-path request counts (and whether a redirect "leak" target was ever
#  contacted with the Authorization header).  `input` may be one string or an
#  array of them, as with OpenAI; /batch/v1/embeddings serves the same answers
#  as /custom so a test can count the requests one operation made.
#
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MAIN_PORT = 19481
LEAK_PORT = 19482          # a distinct port stands in for a "different host"

_lock = threading.Lock()
_counts = {}
_leak_auth_seen = [False]   # set true if the leak target is ever hit with a bearer token


def _bump(path):
    with _lock:
        _counts[path] = _counts.get(path, 0) + 1
        return _counts[path]


class Handler(BaseHTTPRequestHandler):
    def _json(self, code, obj):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _embed(self):
        length = int(self.headers.get("Content-Length", "0"))
        request = json.loads(self.rfile.read(length)) if length else {}
        texts = request.get("input")
        if isinstance(texts, str):
            texts = [texts]
        if (request.get("model") != "mock-embed-4" or not isinstance(texts, list) or not texts
                or not all(isinstance(t, str) for t in texts)):
            self.send_error(400)
            return
        data = [{"index": i,
                 "embedding": [1.0, 0.0, 0.0, 0.0] if "alpha" in t else [0.0, 1.0, 0.0, 0.0]}
                for i, t in enumerate(texts)]
        self._json(200, {"data": data})

    def do_GET(self):
        if self.path == "/stats":
            with _lock:
                self._json(200, {"counts": dict(_counts), "leak_auth_seen": _leak_auth_seen[0]})
            return
        self.send_error(404)

    def do_POST(self):
        # Drain the body first so keep-alive stays sane.
        n = _bump(self.path)

        # The redirect "leak" target: records whether it was reached at all, and
        # whether it received the Authorization header.  With n_redirects=0 the
        # client must never get here.
        if self.path == "/leak/v1/embeddings":
            if self.headers.get("Authorization"):
                with _lock:
                    _leak_auth_seen[0] = True
            self._embed()
            return

        # Happy path (requires the bearer token).
        if self.path in ("/custom/v1/embeddings", "/batch/v1/embeddings"):
            if self.headers.get("Authorization") != "Bearer test-provider-key":
                self.send_error(401)
                return
            self._embed()
            return

        # 302 to a different-host (different-port) target: the client must NOT
        # follow it (that would resend the Authorization header off-origin).
        if self.path == "/redirect/v1/embeddings":
            self.send_response(302)
            self.send_header("Location", "http://127.0.0.1:%d/leak/v1/embeddings" % LEAK_PORT)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        # Transient: 429 on the first request, then 200 -> proves 429 is retried.
        if self.path == "/flaky/v1/embeddings":
            if n <= 1:
                self.send_response(429)
                self.send_header("Retry-After", "1")
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
            if self.headers.get("Authorization") != "Bearer test-provider-key":
                self.send_error(401)
                return
            self._embed()
            return

        # Always 500 -> proves retryable 5xx is retried up to the cap then fails.
        if self.path == "/fail500/v1/embeddings":
            self.send_response(500)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        # Always 401 -> proves a terminal 4xx is NOT retried (count stays 1).
        if self.path == "/unauth/v1/embeddings":
            self.send_response(401)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        self.send_error(404)

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    leak = ThreadingHTTPServer(("127.0.0.1", LEAK_PORT), Handler)
    threading.Thread(target=leak.serve_forever, daemon=True).start()
    ThreadingHTTPServer(("127.0.0.1", MAIN_PORT), Handler).serve_forever()
