import argparse
from http.server import ThreadingHTTPServer
from urllib.parse import urlsplit

from sign_in_http_server import SignInFixtureHandler, SignInFixtureState


class LogoutFixtureState(SignInFixtureState):
    def reset(self, configuration):
        super().reset(configuration)
        with self.lock:
            self.logout_requests = 0

    def snapshot(self):
        result = super().snapshot()
        with self.lock:
            result.update({
                'logoutRequests': self.logout_requests,
            })
        return result


class LogoutFixtureHandler(SignInFixtureHandler):
    def do_DELETE(self):
        state = self.server.fixture_state
        path = urlsplit(self.path).path
        with state.lock:
            state.logout_requests += 1
            state.unexpected.append('DELETE ' + path)
        self.respond(404, {'status': 404, 'message': 'No logout endpoint.', 'data': {}})


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
