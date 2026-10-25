var response = http.get(TEST_SERVER + '/__test/stats');
if (response.status !== 200) throw new Error('Fixture local indisponível');
output.stats = json(response.body);
