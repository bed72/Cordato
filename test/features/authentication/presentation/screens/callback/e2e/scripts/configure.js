var token = 'fixture.verification.token';
var status = SCENARIO === 'invalid' ? 400 : (SCENARIO === 'failure' ? 500 : 204);
var result = http.post(TEST_SERVER + '/__test/reset', {
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({token: token, status: status, gate: SCENARIO === 'loading'})
});
if (result.status !== 200) throw new Error('Não foi possível configurar a fixture local.');
output.callbackLink = CALLBACK_BASE + '?token=' + encodeURIComponent(token);
