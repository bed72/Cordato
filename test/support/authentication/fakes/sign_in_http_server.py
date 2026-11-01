import argparse
import calendar
import datetime
import json
import socket
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit


class SignInFixtureState:
    def __init__(self):
        self.lock = threading.Lock()
        self.release = threading.Event()
        self.reset({})

    def reset(self, configuration):
        with self.lock:
            self.release.set()
            self.release = threading.Event()
            self.configuration = configuration
            self.requests = 0
            self.completed = 0
            self.refresh_requests = 0
            self.credentials_match = True
            self.unexpected = []

    def snapshot(self):
        with self.lock:
            return {
                'requests': self.requests,
                'completed': self.completed,
                'refreshRequests': self.refresh_requests,
                'credentialsMatch': self.credentials_match,
                'unexpected': list(self.unexpected),
            }


class SignInFixtureHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def respond(self, status, body):
        encoded = b'' if status == 204 else json.dumps(body).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(encoded)))
        self.end_headers()
        try:
            self.wfile.write(encoded)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def read_json(self):
        length = int(self.headers.get('Content-Length', '0'))
        return json.loads(self.rfile.read(length)) if length else {}

    def do_POST(self):
        path = urlsplit(self.path).path
        state = self.server.fixture_state
        if path == '/__test/reset':
            state.reset(self.read_json())
            self.respond(200, state.snapshot())
            return
        if path == '/__test/release':
            state.release.set()
            self.respond(200, state.snapshot())
            return
        if path == '/api/collections/users/auth-refresh':
            with state.lock:
                state.refresh_requests += 1
                authorized = self.headers.get('Authorization') == 'Bearer e2e-opaque-token'
                state.credentials_match = state.credentials_match and authorized
            if not authorized:
                self.respond(401, {'status': 401, 'message': 'Invalid fixture token.', 'data': {}})
                return
            self.respond(200, {'token': 'e2e-opaque-token', 'record': {'id': 'e2e-user', 'verified': True}})
            return
        if path != '/api/collections/users/auth-with-password':
            with state.lock:
                state.unexpected.append('POST ' + path)
            self.respond(404, {'errors': [{'detail': 'Fixture ausente'}]})
            return

        body = self.read_json()
        with state.lock:
            index = state.requests
            state.requests += 1
            configuration = state.configuration
            release = state.release
            responses = configuration.get('responses', [])
            response = responses[min(index, len(responses) - 1)] if responses else {
                'status': 500,
                'body': {'errors': [{'detail': 'Resposta não configurada'}]},
            }
            expected = {
                'identity': configuration.get('email', 'Person@Example.com'),
                'password': configuration.get('password', 'Teste1'),
            }
            state.credentials_match = state.credentials_match and body == expected

        if response.get('gate') and not release.wait(timeout=60):
            self.respond(504, {'errors': [{'detail': 'Fixture não liberada'}]})
            return
        if response.get('disconnect'):
            self.close_connection = True
            try:
                self.connection.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            self.connection.close()
        else:
            self.respond(response.get('status', 200), response.get('body', {}))
        with state.lock:
            if state.release is release:
                state.completed += 1

    def do_GET(self):
        parsed = urlsplit(self.path)
        path = parsed.path
        state = self.server.fixture_state
        if path == '/__test/stats':
            self.respond(200, state.snapshot())
            return
        if self.headers.get('Authorization') != 'Bearer e2e-opaque-token':
            self.respond(401, {'errors': [{'detail': 'Token da fixture ausente'}]})
            return
        if path == '/api/users/e2e-user':
            self.respond(200, {
                'data': {
                    'type': 'users',
                    'id': 'e2e-user',
                    'attributes': {
                        'name': 'Pessoa E2E',
                        'email': 'Person@Example.com',
                        'status': 'active',
                        'avatar': None,
                    },
                },
            })
            return
        if path == '/api/expenses':
            self.respond(200, {'data': [], 'links': {'next': None, 'prev': None}})
            return
        if path == '/api/metrics/expenses':
            today = datetime.date.today()
            first = today.replace(day=1).isoformat()
            last = today.replace(day=calendar.monthrange(today.year, today.month)[1]).isoformat()
            query = parse_qs(parsed.query)
            self.respond(200, {
                'data': {
                    'type': 'expense-metrics',
                    'id': 'e2e-metrics',
                    'attributes': {
                        'total_amount': '0',
                        'start_date': query.get('start_date', [first])[0],
                        'end_date': query.get('end_date', [last])[0],
                        'categories': [],
                    },
                },
            })
            return
        with state.lock:
            state.unexpected.append('GET ' + path)
        self.respond(404, {'errors': [{'detail': 'Fixture ausente'}]})


def create_server(port=8765):
    server = ThreadingHTTPServer(('127.0.0.1', port), SignInFixtureHandler)
    server.fixture_state = SignInFixtureState()
    return server


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8765)
    arguments = parser.parse_args()
    server = create_server(arguments.port)
    print('Sign-in fixtures: http://127.0.0.1:' + str(server.server_port), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.fixture_state.release.set()
        server.server_close()
