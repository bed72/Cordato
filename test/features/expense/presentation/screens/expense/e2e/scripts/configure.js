var configuration = {
  responses: [{status: 200, body: {data: {
    type: 'access-tokens', id: 'fixture-token',
    attributes: {token: 'e2e-opaque-token'},
    relationships: {user: {data: {type: 'users', id: 'e2e-user'}}}
  }}}]
};
if (SCENARIO === 'failure') {
  configuration.createResponses = [{status: 422, body: {errors: [{
    status: '422', detail: 'Descrição recusada', source: {pointer: '/data/attributes/description'}
  }]}}, {}];
  configuration.deleteResponses = [{status: 503, body: {errors: [{detail: 'Despesa mantida'}]}}, {}];
}
if (SCENARIO === 'loading') {
  configuration.createResponses = [{gate: true}];
  configuration.deleteResponses = [{gate: true}];
}
if (SCENARIO === 'suggestions-failure') {
  configuration.suggestionsResponses = [{status: 503, body: {errors: [{detail: 'Sugestões indisponíveis'}]}}];
}
if (SCENARIO === 'suggestions-loading') {
  configuration.suggestionsResponses = [{gate: true}];
}
var response = http.post(TEST_SERVER + '/__test/reset', {
  headers: {'Content-Type': 'application/json'}, body: JSON.stringify(configuration)
});
if (response.status !== 200) throw new Error('Fixture local indisponível');
