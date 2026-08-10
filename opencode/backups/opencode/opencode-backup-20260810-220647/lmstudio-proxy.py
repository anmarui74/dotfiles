#!/usr/bin/env python3
"""Proxy OpenCode ↔ LM Studio - VERSIÓN QUE FUNCIONA"""
import json, http.server, urllib.request, sys

LM = "http://localhost:1234"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 4001

class Proxy(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"
    def log_message(self, *args): pass

    def do_GET(self):
        try:
            r = urllib.request.urlopen(urllib.request.Request(f"{LM}{self.path}"), timeout=5)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(r.read())
        except: self.send_error(502)

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        body = json.loads(raw)
        model = body.get("model", "")
        if model.startswith("lmstudio/"):
            body["model"] = model[len("lmstudio/"):]

        msgs = body.get('messages', [])
        if not any(m.get('role') == 'user' for m in msgs):
            body['messages'].append({'role': 'user', 'content': '(cont.)'})

        try:
            r = urllib.request.urlopen(urllib.request.Request(
                f"{LM}{self.path}", data=json.dumps(body).encode(),
                headers={"Content-Type": "application/json"}), timeout=300)

            is_stream = body.get("stream", False)
            if is_stream:
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.send_header("Cache-Control", "no-cache")
                self.end_headers()
                while True:
                    chunk = r.read(65536)
                    if not chunk: break
                    self.wfile.write(chunk)
                    self.wfile.flush()
            else:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(r.read())
        except Exception as e:
            self.send_error(502, str(e)[:200])

http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Proxy).serve_forever()
