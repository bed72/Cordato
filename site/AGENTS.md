# Instruções do site

Estas regras se aplicam somente a `site/`. Leia
[`ARQUITECTURE.md`](ARQUITECTURE.md) antes de alterar a implementação.
Não altere o app Flutter, targets nativos ou release Android incidentalmente.
Os testes de UI do site não mudam a política sem UI do aplicativo.

## Implementação

- O site é HTML e CSS estáticos, sem framework, build ou JavaScript de runtime.
- Arquivos publicados ficam em `public/`; não publique testes, ferramentas,
  node_modules ou documentos operacionais.
- Conteúdo deve estar no HTML, legível mesmo com JavaScript desabilitado.
- Use links e âncoras nativos, SVG inline decorativo e disclosures `details/summary`.
- Preserve os arquivos de imagens e a fonte Inter local.
- Preserve os tokens, cores, espaçamentos, tipografia e breakpoints de
  `public/styles.css`. Não faça redesign incidental.
- Não introduza frameworks, ferramentas de build, SPA, bibliotecas de
  ícones, HTTP, autenticação ou armazenamento no navegador.
- Código novo não recebe comentários explicativos; explicações ficam em Markdown.
- Preserve avisos de licenças dos estilos e ícones em
  `public/third-party-notices.txt`.

## Conteúdo e limites

- O app usa perfil e despesas locais, sem cadastro, backend, áudio ou IA.
- Exportação CSV local é acessada em Configurações → Exportar despesas, com
  compartilhamento nativo escolhido pelo usuário. Não é criptografada nem um
  backup restaurável; não prometa sincronização, importação ou recuperação remota.
- Distinga dados locais, cópias do sistema, mensagens de suporte e logs do host.
- Preserve contato para dados de versões antigas; não afirme que foram apagados.
- Mantenha as páginas alinhadas ao conteúdo de Information no app.
- Cabeçalho e rodapé são repetidos nos quatro HTMLs para dispensar templates e
  geração. Ao alterá-los, atualize os quatro e verifique a consistência.
- Links e assets devem ser relativos, funcionando tanto na raiz quanto em `/Cordato/`.
- Não mude DNS, visibilidade ou faça deploy sem autorização explícita.

## Acessibilidade e fidelidade

- Preserve headings, landmarks, skip link, foco visível, contraste e textos de imagem.
- Navegação entre documentos é nativa, não emulada por router.
- Preserve teclado, FAQ, índice, texto ampliado e largura de 320px sem overflow.
- Ícones e movimentos usam CSS e respeitam `prefers-reduced-motion`.
- Mudanças de conversão/layout exigem comparação visual antes/depois nas quatro
  páginas em desktop e mobile, além dos testes de acessibilidade.
- Não trate uma comparação em Chromium como garantia para todos os navegadores.

## Ferramentas e testes

Node é opcional para preview e testes, nunca requisito da hospedagem. O servidor
em `tools/serve.mjs` usa somente APIs nativas e deve ficar limitado a localhost.
DevDependencies são permitidas para Playwright, axe e formatação, sem build.
Não adicione dependências de runtime.

Comandos dentro de `site/`:

```bash
node tools/serve.mjs
npm ci
npm test
npm run format:check
npm run test:e2e
```

Workflows ficam em `../.github/workflows/site-*.yml` e exigem actionlint ao mudar.
`site-test.yml` verifica arquivos/preview, teclado, acessibilidade e ausência de
scripts. `site-pages.yml` publica diretamente `site/public`, sem instalar npm.
Reporte verificações e bloqueios reais; não afirme deploy ou certificação sem evidência.
