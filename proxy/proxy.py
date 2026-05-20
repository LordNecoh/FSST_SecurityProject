import os
import json
import http.client
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

# Import external modules
from modules.dedicated_header import DedicatedHeaderSanitizer
from modules.headers_order import HeadersOrderSanitizer

SERVER_HOST = os.environ.get('SERVER_HOST', 'server')
SERVER_PORT = int(os.environ.get('SERVER_PORT', 8001))

# In-memory storage for protected entrypoints
configs = {}

# Dynamic registration of sanitizers
SANITIZERS = {
    "dedicatedheader": DedicatedHeaderSanitizer(),
    "headersorder": HeadersOrderSanitizer()
}

class ProxyHandler(BaseHTTPRequestHandler):
    
    def _forward_request(self, method, path, headers_list, body):
        conn = http.client.HTTPConnection(SERVER_HOST, SERVER_PORT)
        conn.putrequest(method, path, skip_host=True, skip_accept_encoding=True)
        
        for key, value in headers_list:
            conn.putheader(key, value)
        conn.endheaders()
        
        if body:
            conn.send(body)
            
        res = conn.getresponse()
        
        self.send_response(res.status)
        for key, value in res.getheaders():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(res.read())

    def _handle_request(self):
        method = self.command
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else None
        
        headers_list = list(self.headers.items())

        if method == 'POST' and path == '/setup':
            if body:
                data = json.loads(body.decode('utf-8'))
                entrypoint = "/" + data.get('entrypoint', '').lstrip('/')
                leak_type = data.get('type', '')
                if leak_type in SANITIZERS:
                    configs[entrypoint] = leak_type
                    print(f"[*] Proxy protecting entrypoint: {entrypoint} ({leak_type})")

        elif method == 'PUT' and path in configs:
            leak_type = configs[path]
            sanitizer = SANITIZERS.get(leak_type)
            if sanitizer:
                headers_list = sanitizer.sanitize(headers_list)
                print(f"[*] Proxy sanitized PUT request to {path} using {leak_type}")

        self._forward_request(method, self.path, headers_list, body)

    do_GET = _handle_request
    do_POST = _handle_request
    do_PUT = _handle_request

def run(server_class=HTTPServer, handler_class=ProxyHandler, port=8000):
    server_address = ('0.0.0.0', port)
    httpd = server_class(server_address, handler_class)
    print(f"[*] Proxy Server listening on port {port}...")
    httpd.serve_forever()

if __name__ == '__main__':
    run()