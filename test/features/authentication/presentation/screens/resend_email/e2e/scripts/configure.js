var responses = [{status: 204}];
if (SCENARIO === 'failure') {
  responses = [{status: 429, body: {status: 429, message: 'Limite de reenvios atingido.', data: {}}}, {status: 204}];
}
if (SCENARIO === 'loading') {
  responses = [{status: 204, gate: true}];
}
var result = http.post(TEST_SERVER + '/__test/reset', {
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({email: EMAIL, password: PASSWORD, responses: responses})
});
if (result.status !== 200) throw new Error('Não foi possível configurar a fixture local.');
