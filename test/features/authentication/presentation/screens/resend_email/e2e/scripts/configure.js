var responses = [{status: 202}];
if (SCENARIO === 'failure') {
  responses = [{status: 429, body: {errors: [{status: '429', title: 'Aguarde', detail: 'Limite de reenvios atingido.'}]}}, {status: 202}];
}
if (SCENARIO === 'loading') {
  responses = [{status: 202, gate: true}];
}
var result = http.post(TEST_SERVER + '/__test/reset', {
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({email: EMAIL, password: PASSWORD, responses: responses})
});
if (result.status !== 200) throw new Error('Não foi possível configurar a fixture local.');
