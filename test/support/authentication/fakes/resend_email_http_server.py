import argparse
from http.server import ThreadingHTTPServer
from urllib.parse import urlsplit

from sign_in_http_server import SignInFixtureState
from sign_up_http_server import SignUpFixtureHandler


class ResendEmailFixtureHandler(SignUpFixtureHandler):
    def do_POST(self):
        path = urlsplit(self.path).path
        state = self.server.fixture_state
        if path in ['/__test/reset', '/__test/release']:
            return super().do_POST()
        body = self.read_json()
        if path == '/api/collections/users/records':
            with state.lock:
                configuration = state.configuration
                password = configuration.get('password', 'Teste1')
                expected = {
                    'email': configuration.get('email', 'Person@Example.com'),
                    'password': password,
                    'passwordConfirm': password,
                }
                state.credentials_match = (
                    state.credentials_match and body == expected
                    and self.headers.get('Authorization') is None
                )
            self.respond(200, {'id': 'fixture-user', 'verified': False})
            return
        if path != '/api/collections/users/request-verification':
            with state.lock:
                state.unexpected.append('POST ' + path)
            self.respond(404, {'errors': [{'detail': 'Fixture ausente'}]})
            return
        with state.lock:
            index = state.requests
            state.requests += 1
            configuration = state.configuration
            release = state.release
            expected = {
                'email': configuration.get('email', 'Person@Example.com'),
            }
            state.credentials_match = (
                state.credentials_match and body == expected
                and self.headers.get('Authorization') is None
            )
            responses = configuration.get('responses', [{'status': 204}])
            response = responses[min(index, len(responses) - 1)]
        if response.get('gate') and not release.wait(timeout=60):
            self.respond(504, {'errors': [{'detail': 'Fixture não liberada'}]})
            return
        self.respond(response.get('status', 204), response.get('body', {}))
        with state.lock:
            if state.release is release:
                state.completed += 1


def create_server(port=8767):
    server = ThreadingHTTPServer(('127.0.0.1', port), ResendEmailFixtureHandler)
    server.fixture_state = SignInFixtureState()
    return server


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8767)
    server = create_server(parser.parse_args().port)
    print('Resend-email fixtures: http://127.0.0.1:' + str(server.server_port), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.fixture_state.release.set()
        server.server_close()
