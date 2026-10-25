var logoutResponses = [{status: 204}];
if (SCENARIO === 'failure') {
  logoutResponses = [{status: 503, body: {errors: [{status: '503', title: 'Erro ao sair', detail: 'Não foi possível revogar o acesso.'}]}}, {status: 204}];
}
if (SCENARIO === 'loading') {
  logoutResponses = [{status: 204, gate: true}];
}
var result = http.post(TEST_SERVER + '/__test/reset', {
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({
    email: EMAIL,
    password: PASSWORD,
    responses: [{status: 200, body: {data: {
      type: 'access-tokens',
      attributes: {token: 'e2e-opaque-token'},
      relationships: {user: {data: {type: 'users', id: 'e2e-user'}}}
    }}}],
    logoutResponses: logoutResponses
  })
});
if (result.status !== 200) throw new Error('Não foi possível configurar a fixture local.');
