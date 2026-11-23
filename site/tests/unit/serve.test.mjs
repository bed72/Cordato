import assert from 'node:assert/strict';
import { mkdtemp, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

import { createStaticServer } from '../../tools/serve.mjs';

async function withServer(run, directory) {
  const server = createStaticServer(directory);
  await new Promise((ready) => server.listen(0, '127.0.0.1', ready));
  const origin = `http://127.0.0.1:${server.address().port}`;

  try {
    await run(origin);
  } finally {
    server.closeAllConnections();
    await new Promise((done) => server.close(done));
  }
}

for (const path of ['/', '/privacy/', '/terms/', '/support/']) {
  test(`serves ${path} as a full HTML document`, async () => {
    await withServer(async (origin) => {
      const response = await fetch(origin + path);

      assert.equal(response.status, 200);
      assert.equal(response.headers.get('content-type'), 'text/html; charset=utf-8');
      assert.match(await response.text(), /<h1/);
    });
  });
}

test('canonicalizes directory URLs and supports direct refresh without SPA fallback', async () => {
  await withServer(async (origin) => {
    const redirect = await fetch(origin + '/privacy', { redirect: 'manual' });
    const first = await fetch(origin + '/privacy/');
    const refresh = await fetch(origin + '/privacy/');

    assert.equal(redirect.status, 308);
    assert.equal(redirect.headers.get('location'), '/privacy/');
    assert.equal(await first.text(), await refresh.text());
  });
});

for (const path of [
  '/unknown',
  '/api/users',
  '/delete-account',
  '/authentication/reset-password',
  '/.well-known/assetlinks.json',
]) {
  test(`does not serve an HTML fallback for ${path}`, async () => {
    await withServer(async (origin) => {
      const response = await fetch(origin + path);

      assert.equal(response.status, 404);
      assert.equal(await response.text(), '');
    });
  });
}

test('HEAD returns metadata without a body and writes are rejected', async () => {
  await withServer(async (origin) => {
    const head = await fetch(origin + '/styles.css', { method: 'HEAD' });
    const post = await fetch(origin + '/', { method: 'POST' });

    assert.equal(head.status, 200);
    assert.equal(head.headers.get('content-type'), 'text/css; charset=utf-8');
    assert.ok(Number(head.headers.get('content-length')) > 0);
    assert.equal(await head.text(), '');
    assert.equal(post.status, 405);
    assert.equal(post.headers.get('allow'), 'GET, HEAD');
  });
});

test('rejects malformed escapes and encoded directory traversal', async () => {
  await withServer(async (origin) => {
    const malformed = await fetch(origin + '/%ZZ');
    const traversal = await fetch(origin + '/..%2fpackage.json');

    assert.equal(malformed.status, 400);
    assert.equal(traversal.status, 403);
  });
});

test('does not follow symlinks outside the served directory', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'cordato-static-'));
  const external = await mkdtemp(join(tmpdir(), 'cordato-external-'));
  try {
    await writeFile(join(external, 'private.txt'), 'not public');
    await symlink(external, join(directory, 'external'));

    await withServer(async (origin) => {
      const response = await fetch(origin + '/external/private.txt');

      assert.equal(response.status, 403);
      assert.equal(await response.text(), '');
    }, directory);
  } finally {
    await rm(directory, { recursive: true, force: true });
    await rm(external, { recursive: true, force: true });
  }
});
