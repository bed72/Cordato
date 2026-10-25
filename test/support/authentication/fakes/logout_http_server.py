import argparse
from http.server import ThreadingHTTPServer
from urllib.parse import urlsplit

from sign_in_http_server import SignInFixtureHandler, SignInFixtureState


class LogoutFixtureState(SignInFixtureState):
    def reset(self, configuration):
        super().reset(configuration)
        with self.lock:
            self.logout_requests = 0
            self.logout_completed = 0
            self.logout_authorized = True

    def snapshot(self):
        result = super().snapshot()
        with self.lock:
            result.update({
                'logoutRequests': self.logout_requests,
                'logoutCompleted': self.logout_completed,
                'logoutAuthorized': self.logout_authorized,
            })
        return result


class LogoutFixtureHandler(SignInFixtureHandler):
    def do_DELETE(self):
        state = self.server.fixture_state
        path = urlsplit(self.path).path
        if path != '/api/authentication/sign-out':
            with state.lock:
                state.unexpected.append('DELETE ' + path)
            self.respond(404, {'errors': [{'detail': 'Fixture ausente'}]})
            return
        with state.lock:
            index = state.logout_requests
            state.logout_requests += 1
            release = state.release
            state.logout_authorized = (
                state.logout_authorized
                and self.headers.get('Authorization') == 'Bearer e2e-opaque-token'
            )
            responses = state.configuration.get('logoutResponses', [{'status': 204}])
            response = responses[min(index, len(responses) - 1)]
        if response.get('gate') and not release.wait(timeout=60):
            self.respond(504, {'errors': [{'detail': 'Fixture não liberada'}]})
            return
        status = response.get('status', 204)
        if status == 204:
            self.send_response(204)
            self.send_header('Content-Length', '0')
            self.end_headers()
        else:
            self.respond(status, response.get('body', {}))
        with state.lock:
            if state.release is release:
                state.logout_completed += 1


def create_server(port=8769):
    server = ThreadingHTTPServer(('127.0.0.1', port), LogoutFixtureHandler)
    server.fixture_state = LogoutFixtureState()
    return server


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8769)
    server = create_server(parser.parse_args().port)
    print('Logout fixtures: http://127.0.0.1:' + str(server.server_port), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.fixture_state.release.set()
        server.server_close()
