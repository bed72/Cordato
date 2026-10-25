var configuration = {
  email: 'Person@Example.com',
  password: 'Teste1',
  responses: [{status: 200, body: {data: {
    type: 'access-tokens', id: 'fixture-token',
    attributes: {token: 'e2e-opaque-token'},
    relationships: {user: {data: {type: 'users', id: 'e2e-user'}}}
  }}}],
  avatarResponses: SCENARIO === 'loading' ? [{gate: true}] : [{}],
  deleteResponses: [{}]
};
if (SCENARIO === 'failure') {
  configuration.avatarResponses = [{status: 422, body: {errors: [{detail: 'Avatar recusado'}]}}, {}];
  configuration.deleteResponses = [{status: 503, body: {errors: [{detail: 'Conta mantida'}]}}, {}];
}
if (SCENARIO === 'edit-failure') {
  configuration.nameResponses = [{status: 422, body: {errors: [{
    status: '422', detail: 'Nome recusado', source: {pointer: '/data/attributes/name'}
  }]}}, {}];
}
if (SCENARIO === 'edit-loading') configuration.nameResponses = [{gate: true}];
var result = http.post(TEST_SERVER + '/__test/reset', {
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify(configuration)
});
if (result.status !== 200) throw new Error('Fixture local indisponível.');
