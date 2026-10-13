import argparse
import http.client
import ssl
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
parser.add_argument('--port', type=int, default=8765)
parser.add_argument('--host', default='trocado.test')
args = parser.parse_args()
ca_root = subprocess.check_output(['mkcert', '-CAROOT'], text=True).strip()
tls_context = ssl.create_default_context(cafile=str(Path(ca_root) / 'rootCA.pem'))
hop_headers = {'connection', 'keep-alive', 'transfer-encoding', 'upgrade',
               'proxy-authenticate', 'proxy-authorization', 'te', 'trailer'}


class ApiProxyHandler(BaseHTTPRequestHandler):
    def forward(self):
        connection = http.client.HTTPSConnection(
            args.host, context=tls_context, timeout=30,
        )
        try:
            length = int(self.headers.get('Content-Length', '0'))
            body = self.rfile.read(length) if length else None
            headers = {
                key: value for key, value in self.headers.items()
                if key.lower() not in hop_headers | {'host'}
            }
            connection.request(self.command, self.path, body, headers)
            response = connection.getresponse()
            payload = response.read()
            self.send_response(response.status)
            for key, value in response.getheaders():
                if key.lower() not in hop_headers | {'content-length'}:
                    self.send_header(key, value)
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            if self.command != 'HEAD':
                self.wfile.write(payload)
        except (OSError, http.client.HTTPException):
            self.send_error(502, 'Local API unavailable')
        finally:
            connection.close()

    do_GET = forward
    do_POST = forward
    do_PATCH = forward
    do_PUT = forward
    do_DELETE = forward
    do_OPTIONS = forward
    do_HEAD = forward

    def log_message(self, format, *values):
        pass


server = ThreadingHTTPServer(('127.0.0.1', args.port), ApiProxyHandler)
subprocess.run([
    'adb', '-s', args.device, 'reverse',
    f'tcp:{args.port}', f'tcp:{args.port}',
], check=True)
print(f'Android USB API: http://127.0.0.1:{args.port}/api/', flush=True)
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
finally:
    server.server_close()
