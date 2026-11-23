import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const root = new URL('../../public/', import.meta.url);
const pages = ['index.html', 'privacy/index.html', 'terms/index.html', 'support/index.html'];

for (const path of pages) {
  test(`${path} contains complete accessible content without a framework or scripts`, async () => {
    const html = await readFile(new URL(path, root), 'utf8');

    assert.match(html, /<html lang="pt-BR" class="dark">/);
    assert.equal([...html.matchAll(/<h1\b/g)].length, 1);
    assert.match(html, /<main id="main-content" tabindex="-1">/);
    assert.match(html, /Pular para o conteúdo/);
    assert.match(html, /href="\/styles\.css"/);
    assert.doesNotMatch(html, /<script\b|<base\b|_ng|ng-version|<app-|routerlink|delete-account/i);
    assert.match(html, /developer\.bed@gmail\.com|Fale com a gente/);
  });

  test(`${path} has valid local page, fragment, stylesheet, image and font links`, async () => {
    const html = await readFile(new URL(path, root), 'utf8');
    const base = new URL(path, 'https://app.cordato.cloud/');
    const links = [...html.matchAll(/(?:href|src)="([^"]+)"/g)].map((match) => match[1]);

    for (const href of links) {
      const url = new URL(href, base);
      if (url.origin !== base.origin) {
        assert.equal(url.protocol, 'mailto:');
        continue;
      }

      let target = new URL('.' + url.pathname, root);
      if ((await stat(target)).isDirectory()) {
        target = new URL('index.html', target.href.endsWith('/') ? target : target.href + '/');
      }
      assert.equal((await stat(target)).isFile(), true, href);

      if (url.hash) {
        const document = await readFile(target, 'utf8');
        assert.ok(document.includes(`id="${decodeURIComponent(url.hash.slice(1))}"`), href);
      }
    }
  });
}

test('privacy distinguishes local records, hosting, support and older versions', async () => {
  const html = await readFile(new URL('privacy/index.html', root), 'utf8');

  for (const text of [
    'seed do avatar',
    'sem conta remota',
    'não possui criptografia adicional',
    'endereço IP',
    'provedores de e-mail',
    'backups do sistema',
    'versões antigas com cadastro',
    'LGPD',
    '2026-11-23',
    'Versão 2.1',
  ]) {
    assert.ok(html.includes(text), text);
  }
  assert.doesNotMatch(html, /Resend|OpenRouter|três cópias automáticas/);
});

test('terms and support do not promise remote recovery or app backups', async () => {
  const terms = await readFile(new URL('terms/index.html', root), 'utf8');
  const support = await readFile(new URL('support/index.html', root), 'utf8');

  assert.ok(terms.includes('Não há cadastro, login ou senha'));
  assert.ok(terms.includes('não processa nem confirma pagamentos'));
  assert.ok(terms.includes('não oferece exportação'));
  assert.ok(support.includes('não pode apagar o banco local remotamente'));
  assert.ok(support.includes('podem ser perdidos'));
  assert.equal([...support.matchAll(/<details\b/g)].length, 10);
});

test('publishing is a direct static upload with no runtime or build dependencies', async () => {
  const packageJson = JSON.parse(await readFile(new URL('../../package.json', import.meta.url)));
  const workflow = await readFile(
    new URL('../../../.github/workflows/site-pages.yml', import.meta.url),
    'utf8',
  );

  assert.equal(packageJson.dependencies, undefined);
  assert.equal(packageJson.scripts.build, undefined);
  assert.equal(packageJson.scripts['build:pages'], undefined);
  assert.match(workflow, /path: site\/public/);
  assert.doesNotMatch(workflow, /npm |setup-node|flutter|LOCALSTORE_READ_TOKEN/);
  assert.equal(await readFile(new URL('.nojekyll', root), 'utf8'), '');
  assert.ok(fileURLToPath(root).endsWith('/site/public/'));
});

test('all documents share the same header and footer without runtime templates', async () => {
  const documents = await Promise.all(pages.map((path) => readFile(new URL(path, root), 'utf8')));
  const header = /<header class="site-header">[\s\S]*?<\/header>/;
  const footer = /<footer class="site-footer">[\s\S]*?<\/footer>/;
  const referenceHeader = documents[0].match(header)?.[0];
  const referenceFooter = documents[0].match(footer)?.[0];

  assert.ok(referenceHeader);
  assert.ok(referenceFooter);
  for (const document of documents) {
    assert.equal(document.match(header)?.[0], referenceHeader);
    assert.equal(document.match(footer)?.[0], referenceFooter);
  }
});
