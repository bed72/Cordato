var response = {status: 201};
var responses = [response];
if (SCENARIO === 'failure') {
  responses = [{status: 409, body: {errors: [{status: '409', detail: 'E-mail já cadastrado.', source: {pointer: '/data/attributes/email'}}]}}, response];
}
if (SCENARIO === 'loading') {
  responses = [{status: 201, gate: true}];
}
var result = http.post(TEST_SERVER + '/__test/reset', {
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({email: EMAIL, password: PASSWORD, responses: responses})
});
if (result.status !== 200) throw new Error('Não foi possível configurar a fixture local.');
