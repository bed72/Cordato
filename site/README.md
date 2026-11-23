# Site do Cordato

Site estático do app, em `site/` no repositório
[bed72/Cordato](https://github.com/bed72/Cordato).
**HTML + CSS, sem framework, JavaScript, npm ou build para publicar.**
Imagens, fonte Inter e design foram preservados. O projeto web original não foi alterado.

## Testar localmente

Na raiz do repositório:

```bash
node site/tools/serve.mjs
```

Abra **http://127.0.0.1:4200**. Não precisa de `npm install` ou `npm ci` para o preview.
Qualquer outro servidor estático que sirva `site/public/` também funciona.
Não abra os HTMLs por `file://`, pois os assets usam caminhos a partir da raiz.

| Página       | Endereço    |
| ------------ | ----------- |
| Apresentação | `/`         |
| Privacidade  | `/privacy/` |
| Termos       | `/terms/`   |
| Ajuda        | `/support/` |

Para usar outra porta: `node site/tools/serve.mjs 4201`.

## Publicar no GitHub Pages

Publique **somente `site/public/`**, como está. Não existe etapa de geração.
O workflow manual
[`site-pages.yml`](../.github/workflows/site-pages.yml)
faz esse upload na `main`, sem instalar dependências npm e sem executar Flutter.

O domínio pretendido é `app.cordato.cloud`.
Assets absolutos pressupõem domínio na raiz: `bed72.github.io/Cordato/` não funciona
sem adaptar os caminhos. Configuração e transição em
[`deploy/README.md`](deploy/README.md).

No GitHub Free, Pages exige repositório público. Publicar o repositório também
expõe o app e seu histórico; não altere a visibilidade sem autorização e revisão
de dados sensíveis. Nenhum deploy ou mudança de DNS foi feito por esta conversão.

## Manutenção

- Edite os HTMLs em `public/` e o CSS em `public/styles.css`.
- Cabeçalho e rodapé estão repetidos nas quatro páginas para dispensar templates/build.
- Conteúdo, links, índice e FAQ funcionam com JavaScript desabilitado.
- Os documentos refletem o app local, sem conta, backend, áudio ou IA.
- Preserve os limites: sem exportação, sincronização, backup próprio ou recuperação.
- Mensagens de suporte e logs da hospedagem são distintos do banco local do app.
- Mantenha o contato para dados de versões antigas; retirar o formulário não apaga dados antigos.
- O conteúdo do app em
  [`InformationContent`](../lib/features/information/presentation/content/information_content.dart)
  é a referência para consistência, considerando os tratamentos específicos da web.

Os documentos web são versão 2.1 de 23/11/2026, baseados na versão 2.1 de
21/11/2026 do aplicativo. A conversão estática não mudou seu conteúdo.
Avisos de terceiros estão em `public/third-party-notices.txt`.

## Verificações opcionais

Node 24+ e npm são usados **apenas nas ferramentas de desenvolvimento e testes**.
Dentro de `site/`:

```bash
npm ci
npm test
npm run format:check
npx playwright install chromium
npm run test:e2e
```

A CI é [`site-test.yml`](../.github/workflows/site-test.yml).
Testes Node verificam HTML, links e preview. Playwright verifica quatro tamanhos,
axe, teclado, movimento reduzido, texto ampliado e navegação sem JavaScript.
Não são certificação de acessibilidade nem homologação em aparelhos reais.

Na conversão, as quatro páginas foram comparadas à versão anterior em 320, 390,
768 e 1440px: **16 capturas full-page idênticas no mesmo Chromium**, com fonte
carregada e movimento reduzido. Isso não promete renderização idêntica em todos os navegadores.

Leia [`AGENTS.md`](AGENTS.md) e [`ARQUITECTURE.md`](ARQUITECTURE.md) antes de alterar o site.
