import argparse
import sys
from pathlib import Path
from http.server import ThreadingHTTPServer
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'authentication' / 'fakes'))
from sign_in_http_server import SignInFixtureHandler, SignInFixtureState


class UserFixtureState(SignInFixtureState):
    def reset(self, configuration):
        super().reset(configuration)
        with self.lock:
            self.avatar = None
            self.name = 'Pessoa E2E'
            self.avatar_requests = 0
            self.name_requests = 0
            self.delete_requests = 0
            self.authorized = True

    def snapshot(self):
        result = super().snapshot()
        with self.lock:
            result.update(avatarRequests=self.avatar_requests,
                          nameRequests=self.name_requests, name=self.name,
                          deleteRequests=self.delete_requests,
                          authorized=self.authorized, avatar=self.avatar)
        return result

    def user(self):
        with self.lock:
            return {'data': {'type': 'users', 'id': 'e2e-user', 'attributes': {
                'name': self.name, 'email': 'Person@Example.com',
                'status': 'active', 'avatar': self.avatar,
            }}}


class UserFixtureHandler(SignInFixtureHandler):
    def do_GET(self):
        if urlsplit(self.path).path != '/api/users/e2e-user':
            return super().do_GET()
        if self.headers.get('Authorization') != 'Bearer e2e-opaque-token':
            self.respond(401, {'errors': [{'detail': 'Token da fixture ausente'}]})
            return
        self.respond(200, self.server.fixture_state.user())

    def do_PATCH(self):
        self.mutate('avatar')

    def do_DELETE(self):
        self.mutate('delete')

    def mutate(self, operation):
        state = self.server.fixture_state
        path = urlsplit(self.path).path
        if path != '/api/users/e2e-user':
            with state.lock:
                state.unexpected.append(self.command + ' ' + path)
            self.respond(404, {'errors': [{'detail': 'Fixture ausente'}]})
            return
        authorized = self.headers.get('Authorization') == 'Bearer e2e-opaque-token'
        with state.lock:
            state.authorized = state.authorized and authorized
        if not authorized:
            self.respond(401, {'errors': [{'detail': 'Token da fixture ausente'}]})
            return
        payload = self.read_json() if operation != 'delete' else None
        if operation != 'delete':
            data = payload.get('data', {})
            attributes = data.get('attributes', {})
            operation = 'name' if set(attributes) == {'name'} else 'avatar'
            if (data.get('type') != 'users' or data.get('id') != 'e2e-user'
                    or set(attributes) != {operation}
                    or not isinstance(attributes[operation], str)):
                self.respond(422, {'errors': [{'detail': 'Payload inválido'}]})
                return
        with state.lock:
            counter = operation + '_requests'
            index = getattr(state, counter)
            setattr(state, counter, index + 1)
            responses = state.configuration.get(operation + 'Responses', [{}])
            response = responses[min(index, len(responses) - 1)]
            release = state.release
        if response.get('gate') and not release.wait(timeout=60):
            self.respond(504, {'errors': [{'detail': 'Fixture não liberada'}]})
            return
        status = response.get('status', 204 if operation == 'delete' else 200)
        if status == 204:
            self.send_response(204)
            self.send_header('Content-Length', '0')
            self.end_headers()
        elif status == 200 and operation != 'delete':
            with state.lock:
                if state.release is release:
                    setattr(state, operation, payload['data']['attributes'][operation])
            self.respond(200, state.user())
        else:
            self.respond(status, response.get('body', {}))


def create_server(port=8770):
    server = ThreadingHTTPServer(('127.0.0.1', port), UserFixtureHandler)
    server.fixture_state = UserFixtureState()
    return server


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8770)
    server = create_server(parser.parse_args().port)
    print('User fixtures: http://127.0.0.1:' + str(server.server_port), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.fixture_state.release.set()
        server.server_close()
