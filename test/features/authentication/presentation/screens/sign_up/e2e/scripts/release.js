var result = http.post(TEST_SERVER + '/__test/release');
if (result.status !== 200) throw new Error('Não foi possível liberar a fixture.');
