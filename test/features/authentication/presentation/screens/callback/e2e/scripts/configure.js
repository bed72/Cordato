var path = '/api/email-verification/12/hash?expires=123&signature=e2e%2Bsignature';
var status = SCENARIO === 'invalid' ? 403 : (SCENARIO === 'failure' ? 500 : 204);
var result = http.post(TEST_SERVER + '/__test/reset', {
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({verificationPath: path, status: status, gate: SCENARIO === 'loading'})
});
if (result.status !== 200) throw new Error('Não foi possível configurar a fixture local.');
output.callbackLink = CALLBACK_BASE + '?verification_url=' + encodeURIComponent(TEST_SERVER + path);
