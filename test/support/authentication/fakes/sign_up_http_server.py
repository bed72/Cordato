import argparse
from urllib.parse import urlsplit
from http.server import ThreadingHTTPServer

from sign_in_http_server import SignInFixtureHandler, SignInFixtureState


class SignUpFixtureHandler(SignInFixtureHandler):
    def do_POST(self):
        path = urlsplit(self.path).path
        state = self.server.fixture_state
        if path in ['/__test/reset', '/__test/release']:
            return super().do_POST()
        if path != '/api/authentication/sign-up':
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
            password = configuration.get('password', 'Teste1')
            expected = {'data': {
                'type': 'sign-ups',
                'attributes': {
                    'email': configuration.get('email', 'Person@Example.com'),
                    'name': 'Trocado',
                    'password': password,
                    'password_confirmation': password,
                },
            }}
            state.credentials_match = (
                state.credentials_match and body == expected
                and self.headers.get('Authorization') is None
            )
            responses = configuration.get('responses', [{'status': 201}])
            response = responses[min(index, len(responses) - 1)]
        if response.get('gate') and not release.wait(timeout=60):
            self.respond(504, {'errors': [{'detail': 'Fixture não liberada'}]})
            return
        self.respond(response.get('status', 201), response.get('body', {}))
        with state.lock:
            if state.release is release:
                state.completed += 1

    def do_GET(self):
        if urlsplit(self.path).path == '/__test/stats':
            self.respond(200, self.server.fixture_state.snapshot())
            return
        state = self.server.fixture_state
        with state.lock:
            state.unexpected.append('GET ' + urlsplit(self.path).path)
        self.respond(404, {'errors': [{'detail': 'Fixture ausente'}]})


def create_server(port=8766):
    server = ThreadingHTTPServer(('127.0.0.1', port), SignUpFixtureHandler)
    server.fixture_state = SignInFixtureState()
    return server


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8766)
    server = create_server(parser.parse_args().port)
    print('Sign-up fixtures: http://127.0.0.1:' + str(server.server_port), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.fixture_state.release.set()
        server.server_close()
