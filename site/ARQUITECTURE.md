# Arquitetura do site Cordato

## Objetivo

Site público em `site/` no repositório [bed72/Cordato](https://github.com/bed72/Cordato),
independente do app Flutter. Foi trazido do projeto web Docarto e convertido de
um framework para HTML/CSS estáticos, preservando a aparência e os assets.
O projeto web original foi mantido.

O site apresenta o aplicativo, Política de Privacidade, Termos e Ajuda. Não é
Flutter Web, backend ou consumidor do banco do app (Drift/SQLite ou legado).
Não há conta, login, exclusão
remota, áudio ou IA. Solicitações sobre dados de versões antigas continuam
orientadas pelo suporte, sem afirmar que esses dados foram apagados.

## Estrutura

```text
site/
├── public/
│   ├── index.html
│   ├── privacy/index.html
│   ├── terms/index.html
│   ├── support/index.html
│   ├── styles.css
│   ├── images/
│   ├── fonts/
│   ├── favicon.png
│   ├── third-party-notices.txt
│   └── .nojekyll
├── tools/serve.mjs
├── tests/unit/
├── tests/e2e/
├── playwright.config.ts
└── package.json / package-lock.json
```

Somente `public/` é publicado. Cada documento contém seu texto completo,
cabeçalho e rodapé: não existe template de runtime, compilador ou gerador.
Alterações no shell devem ser replicadas nas quatro páginas.

As URLs canônicas são `/`, `/privacy/`, `/terms/` e `/support/`. Hosts estáticos
normalmente redirecionam as versões sem barra para o diretório correspondente.
Não há SPA/fallback: URLs desconhecidas recebem 404.
Links e âncoras são nativos; o navegador gerencia navegação, histórico e foco.
FAQ e índice usam `details/summary` e funcionam sem JavaScript.

## Estilos e assets

`public/styles.css` é CSS pronto, com tokens, reset, estilos compartilhados e
estilos das páginas. O reset foi adaptado do CSS anterior gerado por Tailwind,
mas não exige Tailwind nem processamento. Utilities não utilizadas foram retiradas.
Não há dependências de runtime ou scripts nas páginas.

Cores, fonte Inter, imagens WebP, raios, margens e breakpoints foram preservados.
SVGs dos chevrons são inline, decorativos, com animação CSS de hover/foco.
`prefers-reduced-motion` desativa movimentos. Licenças dos trechos derivados
ficam em `public/third-party-notices.txt`.

A migração foi comparada com 16 capturas full-page da versão anterior, nas larguras
320, 390, 768 e 1440px, em Chromium, com a fonte carregada e movimento reduzido.
Todas as capturas finais coincidiram byte a byte com suas referências PNG.
Isso comprova os estados e ambiente comparados, não igualdade universal de
renderização ou de cada quadro das animações em outros navegadores.

## Privacidade e conteúdo

- O site não acessa dados locais do aplicativo nem adiciona analytics ou cookies.
- Imagens e fontes são locais, sem CDN.
- A hospedagem recebe dados técnicos de conexão e pode manter logs.
- Contatar o suporte ou usar o banco para Pix envolve serviços externos.
- O app exporta CSV local por compartilhamento nativo, sem criptografia ou
  restauração. Os destinos escolhidos pelo usuário têm políticas próprias;
  o site não gera arquivos nem acessa despesas.
- Não prometer criptografia adicional, sincronização, backup próprio ou recuperação.
- Não publicar associações legadas de autenticação ou restaurar formulários.
- A política e os termos devem permanecer coerentes com Information no Flutter,
  considerando também os tratamentos específicos da web e do atendimento.
- Revisão textual/testes não representam certificação jurídica.

## Preview, testes e publicação

`tools/serve.mjs` é apenas um servidor local opcional usando Node nativo, sem
pacotes. Ele serve `public/`, redireciona diretórios, retorna 404 sem fallback e
rejeita métodos de escrita e escapes fora da pasta, inclusive por symlinks.
Não é servidor de produção e não é publicado.

O package.json tem somente devDependencies para Playwright, axe e Prettier.
Testes Node verificam conteúdo completo, links, configuração estática e preview.
Playwright verifica quatro viewports, acessibilidade, teclado, texto ampliado,
movimento reduzido e operação com JavaScript desabilitado.

`../.github/workflows/site-test.yml` instala apenas essas ferramentas de
verificação. `site-pages.yml` faz upload direto de `site/public`, manualmente
na `main`, sem Node/npm ou build do projeto. Publicação não modifica Flutter,
Android, banco local do app ou seus secrets.

Links, imagens e CSS usam caminhos relativos; a fonte é relativa ao próprio CSS.
O mesmo artefato funciona na raiz e em `https://bed72.github.io/Cordato/`, endereço
gratuito escolhido para publicação. Um teste de navegador verifica páginas,
fonte, imagens e navegação sob esse prefixo. O preview também pode montar esse
prefixo por `createStaticServer(undefined, '/Cordato/')`.
Domínio personalizado e DNS não são necessários. Qualquer mudança de DNS,
domínio, visibilidade ou publicação ainda exige autorização.
