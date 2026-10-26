import argparse
import datetime
import sys
from pathlib import Path
from http.server import ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'authentication' / 'fakes'))
from sign_in_http_server import SignInFixtureHandler, SignInFixtureState


class ExpenseFixtureState(SignInFixtureState):
    def reset(self, configuration):
        super().reset(configuration)
        with self.lock:
            self.operations = {'create': 0, 'update': 0, 'delete': 0, 'suggestions': 0}
            self.queries = []
            self.authorized = True
            self.items = [{'type': 'expenses', 'id': 'fixture-expense', 'attributes': {
                'description': 'Mercado E2E', 'amount': 1500, 'category': 'food',
                'occurred_on': datetime.date.today().isoformat(),
            }}]

    def snapshot(self):
        result = super().snapshot()
        with self.lock:
            result.update(operations=dict(self.operations), authorized=self.authorized,
                          queries=list(self.queries),
                          amounts=[item['attributes']['amount'] for item in self.items],
                          descriptions=[item['attributes']['description'] for item in self.items])
        return result


class ExpenseFixtureHandler(SignInFixtureHandler):
    def authorize(self):
        valid = self.headers.get('Authorization') == 'Bearer e2e-opaque-token'
        with self.server.fixture_state.lock:
            self.server.fixture_state.authorized &= valid
        if not valid:
            self.respond(401, {'errors': [{'detail': 'Token da fixture ausente'}]})
        return valid

    def do_GET(self):
        path = urlsplit(self.path).path
        if path == '/api/expenses/suggestions':
            return self.suggestions()
        if path not in ['/api/expenses', '/api/expenses/fixture-expense']:
            return super().do_GET()
        if not self.authorize():
            return
        state = self.server.fixture_state
        with state.lock:
            items = list(state.items)
        if path == '/api/expenses':
            self.respond(200, {'data': items, 'links': {'next': None, 'prev': None}})
        elif items:
            self.respond(200, {'data': items[0]})
        else:
            self.respond(404, {'errors': [{'detail': 'Despesa ausente'}]})

    def suggestions(self):
        if not self.authorize():
            return
        state = self.server.fixture_state
        query = parse_qs(urlsplit(self.path).query).get('query', [''])[0]
        with state.lock:
            index = state.operations['suggestions']
            state.operations['suggestions'] += 1
            state.queries.append(query)
            responses = state.configuration.get('suggestionsResponses', [{}])
            response = responses[min(index, len(responses) - 1)]
            release = state.release
        if response.get('gate') and not release.wait(timeout=60):
            self.respond(504, {'errors': [{'detail': 'Fixture não liberada'}]})
            return
        if response.get('status', 200) != 200:
            self.respond(response['status'], response.get('body', {'errors': []}))
            return
        with state.lock:
            if state.release is not release:
                self.respond(409, {'errors': [{'detail': 'Cenário substituído'}]})
                return
        items = [
            {'id': 'market', 'type': 'expense-suggestions', 'attributes': {'description': 'Mercado'}},
            {'id': 'rent', 'type': 'expense-suggestions', 'attributes': {'description': 'Aluguel', 'amount': 160000}},
        ]
        filtered = [item for item in items if query.casefold() in item['attributes']['description'].casefold()]
        self.respond(200, response.get('body', {'data': filtered}))

    def do_POST(self):
        if urlsplit(self.path).path != '/api/expenses':
            return super().do_POST()
        self.mutate('create')

    def do_PATCH(self):
        self.mutate('update')

    def do_DELETE(self):
        self.mutate('delete')

    def mutate(self, operation):
        state = self.server.fixture_state
        path = urlsplit(self.path).path
        expected = '/api/expenses' if operation == 'create' else '/api/expenses/fixture-expense'
        if path != expected:
            with state.lock:
                state.unexpected.append(self.command + ' ' + path)
            self.respond(404, {'errors': [{'detail': 'Fixture ausente'}]})
            return
        if not self.authorize():
            return
        payload = self.read_json() if operation != 'delete' else None
        attributes = payload.get('data', {}).get('attributes', {}) if payload else {}
        if operation != 'delete' and (
                payload.get('data', {}).get('type') != 'expenses'
                or not set(attributes) <= {'description', 'amount', 'occurred_on'}
                or ('amount' in attributes and (type(attributes['amount']) is not int or attributes['amount'] <= 0))
                or (operation == 'create' and set(attributes) != {'description', 'amount', 'occurred_on'})):
            self.respond(422, {'errors': [{'detail': 'Payload inválido'}]})
            return
        with state.lock:
            index = state.operations[operation]
            state.operations[operation] += 1
            responses = state.configuration.get(operation + 'Responses', [{}])
            response = responses[min(index, len(responses) - 1)]
            release = state.release
        if response.get('gate') and not release.wait(timeout=60):
            self.respond(504, {'errors': [{'detail': 'Fixture não liberada'}]})
            return
        status = response.get('status', 204 if operation == 'delete' else 200)
        if status not in [200, 201, 204]:
            self.respond(status, response.get('body', {}))
            return
        with state.lock:
            if state.release is not release:
                self.respond(409, {'errors': [{'detail': 'Cenário substituído'}]})
                return
            if operation == 'delete':
                state.items = []
                item = None
            elif operation == 'create':
                item = {'type': 'expenses', 'id': 'created-' + str(index),
                        'attributes': dict(attributes, category='food')}
                state.items.append(item)
            else:
                state.items[0]['attributes'].update(attributes)
                item = state.items[0]
        if status == 204:
            self.send_response(204)
            self.send_header('Content-Length', '0')
            self.end_headers()
        else:
            self.respond(status, {'data': item})


def create_server(port=8771):
    server = ThreadingHTTPServer(('127.0.0.1', port), ExpenseFixtureHandler)
    server.fixture_state = ExpenseFixtureState()
    return server


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8771)
    server = create_server(parser.parse_args().port)
    print('Expense fixtures: http://127.0.0.1:' + str(server.server_port), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.fixture_state.release.set()
        server.server_close()
