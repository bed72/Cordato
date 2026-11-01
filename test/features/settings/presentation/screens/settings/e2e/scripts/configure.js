var result = http.post(TEST_SERVER + '/__test/reset', {
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({
    email: EMAIL,
    password: PASSWORD,
    responses: [{status: 200, body: {
      token: 'e2e-opaque-token', record: {id: 'e2e-user'}
    }}]
  })
});
if (result.status !== 200) throw new Error('Não foi possível configurar a fixture local.');
