var response = {status: 200, body: {id: 'fixture-user', collectionName: 'users', email: EMAIL, verified: false}};
var responses = [response];
if (SCENARIO === 'failure') {
  responses = [{status: 400, body: {status: 400, message: 'Failed to create record.', data: {email: {code: 'validation_not_unique', message: 'E-mail já cadastrado.'}}}}, response];
}
if (SCENARIO === 'loading') {
  responses = [{status: response.status, body: response.body, gate: true}];
}
var result = http.post(TEST_SERVER + '/__test/reset', {
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({email: EMAIL, password: PASSWORD, responses: responses})
});
if (result.status !== 200) throw new Error('Não foi possível configurar a fixture local.');
