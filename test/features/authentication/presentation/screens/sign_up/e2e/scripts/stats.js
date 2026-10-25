var result = http.get(TEST_SERVER + '/__test/stats');
if (result.status !== 200) throw new Error('Fixture local indisponível.');
output.stats = json(result.body);
