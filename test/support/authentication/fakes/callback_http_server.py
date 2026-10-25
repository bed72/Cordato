import argparse
from http.server import ThreadingHTTPServer
from urllib.parse import urlsplit

from sign_in_http_server import SignInFixtureHandler, SignInFixtureState


class CallbackFixtureHandler(SignInFixtureHandler):
    def do_POST(self):
        if urlsplit(self.path).path in ['/__test/reset', '/__test/release']:
            return super().do_POST()
        state = self.server.fixture_state
        with state.lock:
            state.unexpected.append('POST ' + urlsplit(self.path).path)
        self.respond(404, {'errors': [{'detail': 'Fixture ausente'}]})

    def do_GET(self):
        state = self.server.fixture_state
        if urlsplit(self.path).path == '/__test/stats':
            self.respond(200, state.snapshot())
            return
        if urlsplit(self.path).path != '/api/email-verification/12/hash':
            with state.lock:
                state.unexpected.append('GET ' + urlsplit(self.path).path)
            self.respond(404, {'errors': [{'detail': 'Fixture ausente'}]})
            return
        with state.lock:
            state.requests += 1
            configuration = state.configuration
            release = state.release
            expected = configuration.get('verificationPath')
            state.credentials_match = (
                state.credentials_match and self.path == expected
                and self.headers.get('Authorization') is None
            )
        if configuration.get('gate') and not release.wait(timeout=60):
            self.respond(504, {'errors': [{'detail': 'Fixture não liberada'}]})
            return
        status = configuration.get('status', 204)
        if status == 204:
            self.send_response(204)
            self.send_header('Content-Length', '0')
            self.end_headers()
        else:
            self.respond(status, {'errors': [{'detail': 'Confirmação recusada pela fixture.'}]})
        with state.lock:
            if state.release is release:
                state.completed += 1


def create_server(port=8768):
    server = ThreadingHTTPServer(('127.0.0.1', port), CallbackFixtureHandler)
    server.fixture_state = SignInFixtureState()
    return server


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8768)
    server = create_server(parser.parse_args().port)
    print('Callback fixtures: http://127.0.0.1:' + str(server.server_port), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.fixture_state.release.set()
        server.server_close()
