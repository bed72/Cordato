import AxeBuilder from '@axe-core/playwright';
import { expect, test, type Page } from '@playwright/test';
import { createStaticServer } from '../../tools/serve.mjs';

test.beforeEach(async ({ page }) => {
  await page.route('**/*', (route) =>
    new URL(route.request().url()).origin === 'http://127.0.0.1:4300'
      ? route.continue()
      : route.abort(),
  );
});

async function accessible(page: Page) {
  const findings = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
    .analyze();
  expect(findings.violations).toEqual([]);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
}

for (const [path, title] of [
  ['/', 'Os gastos do dia.'],
  ['/privacy', 'Política de Privacidade'],
  ['/terms', 'Termos de uso'],
  ['/support', 'Ajuda'],
]) {
  test(`direct load, refresh, accessibility and layout: ${path}`, async ({ page }, testInfo) => {
    await page.goto(path);
    await expect(page.getByRole('heading', { level: 1 })).toContainText(title!);
    await page.reload();
    await expect(page.getByRole('heading', { level: 1 })).toContainText(title!);
    await expect(page.locator('a[href="/delete-account"], form')).toHaveCount(0);
    await accessible(page);
    await testInfo.attach('page-layout', {
      body: await page.screenshot({ fullPage: true }),
      contentType: 'image/png',
    });
  });
}

test('privacy columns align at the top on desktop', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.goto('/');
  const introduction = await page.locator('.privacy-story > div').first().boundingBox();
  const explanation = await page.locator('.privacy-story > .story-copy').boundingBox();

  expect(introduction).not.toBeNull();
  expect(explanation).not.toBeNull();
  expect(introduction!.y).toBe(explanation!.y);
});

test('FAQ groups support keyboard interaction and generous touch targets', async ({ page }) => {
  await page.goto('/support');
  for (const title of [
    'Começar e personalizar',
    'Despesas e resumos',
    'Dados, cópias e privacidade',
  ]) {
    await expect(page.getByRole('heading', { level: 2, name: title })).toBeVisible();
  }
  const question = page.locator('summary').filter({ hasText: 'Preciso criar uma conta?' });
  await question.focus();
  await page.keyboard.press('Enter');
  await expect(page.locator('details[open] p')).toContainText('sem cadastro, login ou senha');
  expect((await question.boundingBox())!.height).toBeGreaterThanOrEqual(56);
  await accessible(page);
  await page.keyboard.press('Enter');
  await expect(page.locator('details[open]')).toHaveCount(0);
});

test('document index is keyboard accessible and keeps anchors on the document', async ({
  page,
}) => {
  await page.goto('/privacy');
  await expect(page.getByRole('heading', { name: 'Em resumo' })).toBeVisible();
  const index = page.locator('.document-index');
  await expect(index).not.toHaveAttribute('open');
  await index.locator('summary').focus();
  await page.keyboard.press('Enter');
  const anchor = page
    .getByRole('navigation', { name: 'Nesta página' })
    .getByRole('link', { name: 'Retenção, remoção e recuperação' });
  await anchor.focus();
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL('/privacy/#deletion');
  await expect(page.locator('#deletion')).toBeInViewport();
  await expect(page.locator('#deletion')).toBeFocused();
  await accessible(page);
});

test('reduced motion and doubled text preserve readable, usable pages', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  for (const path of ['/support', '/terms', '/privacy']) {
    await page.goto(path);
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    await page.evaluate(() => {
      document.documentElement.style.fontSize = '200%';
    });
    await accessible(page);
    const back = page.getByRole('link', { name: 'Voltar ao início' });
    await expect(back).toBeVisible();
    expect((await back.boundingBox())!.height).toBeGreaterThanOrEqual(44);
    expect(await back.evaluate((element) => getComputedStyle(element).transitionDuration)).toBe(
      '0s',
    );
  }
});

test('keyboard skip link and native document navigation', async ({ page }) => {
  await page.goto('/');
  await page.keyboard.press('Tab');
  await expect(page.getByRole('link', { name: 'Pular para o conteúdo' })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.getByRole('main')).toBeFocused();
  await page.getByRole('link', { name: 'Fale com a gente', exact: true }).first().click();
  await expect(page).toHaveURL('/support/');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Ajuda');
  await page.keyboard.press('Tab');
  await expect(page.getByRole('link', { name: 'Pular para o conteúdo' })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.getByRole('main')).toBeFocused();
});

test('public pages do not request a backend or persist credentials', async ({ page }) => {
  const unexpectedRequests: string[] = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.origin !== 'http://127.0.0.1:4300' || url.pathname.startsWith('/api/')) {
      unexpectedRequests.push(url.origin + url.pathname);
    }
  });

  for (const path of ['/', '/privacy', '/terms', '/support']) {
    await page.goto(path);
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    expect(await page.evaluate(() => localStorage.length)).toBe(0);
    expect(await page.evaluate(() => sessionStorage.length)).toBe(0);
  }

  expect(unexpectedRequests).toEqual([]);
  expect(await page.context().cookies()).toEqual([]);
});

test('all pages, navigation and disclosures work with JavaScript disabled', async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  const scripts: string[] = [];
  page.on('request', (request) => {
    if (request.resourceType() === 'script') {
      scripts.push(request.url());
    }
  });

  try {
    for (const path of ['/', '/privacy/', '/terms/', '/support/']) {
      const response = await page.goto(path);
      expect(response?.status()).toBe(200);
      await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
      await expect(page.locator('script')).toHaveCount(0);
    }

    const question = page.locator('summary').filter({ hasText: 'Preciso criar uma conta?' });
    await question.focus();
    await page.keyboard.press('Enter');
    await expect(page.locator('details[open] p')).toContainText('sem cadastro, login ou senha');
    await page.getByRole('link', { name: 'Como cuidamos dos seus dados' }).click();
    await expect(page).toHaveURL('/privacy/');
    await page.locator('.document-index summary').click();
    await page.getByRole('link', { name: 'Retenção, remoção e recuperação' }).click();
    await expect(page.locator('#deletion')).toBeInViewport();
    await expect(page.locator('#deletion')).toBeFocused();
    expect(scripts).toEqual([]);
  } finally {
    await context.close();
  }
});

test('icon motion follows keyboard focus and respects reduced motion', async ({ page }) => {
  await page.goto('/privacy/');
  const back = page.getByRole('link', { name: 'Voltar ao início' });
  const path = back.locator('svg path');

  await back.focus();
  await expect(path).toHaveCSS('animation-name', 'chevron-left');
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(path).toHaveCSS('animation-name', 'none');
});

test('project URL loads styles, fonts, images and navigation inside /Cordato/', async ({
  browser,
}) => {
  const server = createStaticServer(undefined, '/Cordato/');
  await new Promise<void>((ready) => server.listen(0, '127.0.0.1', ready));
  const address = server.address();
  if (!address || typeof address === 'string') {
    throw new Error('Expected a local TCP server.');
  }
  const origin = `http://127.0.0.1:${address.port}`;
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  const outsideRequests: string[] = [];
  page.on('request', (request) => {
    if (!new URL(request.url()).pathname.startsWith('/Cordato/')) {
      outsideRequests.push(request.url());
    }
  });

  try {
    for (const path of ['', 'privacy/', 'terms/', 'support/']) {
      const response = await page.goto(origin + '/Cordato/' + path);
      expect(response?.status()).toBe(200);
      expect(
        await page.evaluate(async () => {
          await document.fonts.ready;
          return document.fonts.check('16px Inter');
        }),
      ).toBe(true);
      await expect(page.locator('body')).toHaveCSS('background-color', 'rgb(15, 21, 17)');
      expect(
        await page
          .locator('header.site-header img')
          .evaluate((image: HTMLImageElement) => image.naturalWidth),
      ).toBeGreaterThan(0);
    }
    await page.getByRole('link', { name: 'Como cuidamos dos seus dados' }).click();
    await expect(page).toHaveURL(origin + '/Cordato/privacy/');
    await page.getByRole('link', { name: 'Voltar ao início' }).click();
    await expect(page).toHaveURL(origin + '/Cordato/');
    expect(outsideRequests).toEqual([]);
  } finally {
    await context.close();
    server.closeAllConnections();
    await new Promise<void>((done) => server.close(done));
  }
});
