# Publicação estática sem VPS

O artefato é a própria pasta **`site/public/`**. Não existe build, API, banco,
instalação npm ou servidor de aplicação. Não publique o restante do repositório.

## GitHub Pages

1. Confirme a elegibilidade do repositório: GitHub Free exige repositório público;
   repositório privado exige plano compatível. Não altere a visibilidade sem
   autorização e revisão de arquivos e histórico para dados sensíveis.
2. Em **Settings → Pages**, escolha **GitHub Actions** como fonte.
3. Deixe **Custom domain** vazio para usar o endereço gratuito
   **https://bed72.github.io/Cordato/**. Não é necessário alterar DNS.
4. Depois dos commits na `main` e verificações do site aprovadas, execute
   **Actions → Publish site to GitHub Pages → Run workflow**.
5. Aguarde a conclusão e confira o endereço HTTPS exibido no ambiente `github-pages`.
6. Valide as quatro páginas, acesso direto, refresh, teclado e mobile antes de
   desativar a hospedagem anterior.

Workflow:
[`../../.github/workflows/site-pages.yml`](../../.github/workflows/site-pages.yml).
É manual, limitado à `main`, com ambiente `github-pages`. Faz upload direto de
`site/public` e não executa Node, npm ou compilação do projeto.
Adicioná-lo ao código não publica ou configura domínio/DNS.

O endereço de projeto `bed72.github.io/Cordato/` é suportado por caminhos relativos
em todas as páginas e no CSS. Não há cobrança por renovação de domínio nesse
endereço. Um domínio personalizado continua sendo uma decisão separada.

## Arquivos publicados

```text
index.html
privacy/index.html
terms/index.html
support/index.html
styles.css
images/
fonts/
favicon.png
third-party-notices.txt
.nojekyll
```

Os HTMLs já contêm todo o conteúdo, mesmo sem JavaScript. Diretórios permitem
URLs limpas e refresh sem fallback SPA. `/Cordato/privacy` pode redirecionar para
`/Cordato/privacy/`; o link de privacidade para a Google Play passa a ser
**https://bed72.github.io/Cordato/privacy/**.
URLs desconhecidas recebem 404, sem páginas de autenticação ou exclusão.

Preview opcional na raiz do repositório:

```bash
node site/tools/serve.mjs
```

O servidor é somente local, não faz parte da publicação. O site não usa Docker,
Nginx ou compilação. Publique somente `site/public/`.

## Cuidados da transição

- Confirmar que a versão do app em análise na Play é a versão local.
- Abrir `/`, `/privacy/`, `/terms/` e `/support/` por HTTPS, sem login.
- Testar conteúdo e FAQ com JavaScript desabilitado.
- Conferir imagens, fonte local e ausência de requests de API.
- Alinhar declarações da Play às versões ainda distribuídas, não só ao código novo.
- Confirmar o tratamento de dados antigos e atender solicitações pelo suporte.
  A remoção do formulário não elimina esses dados.
- Não excluir bancos, backups ou serviços anteriores incidentalmente.
- Só dispensar a VPS após conferir se há outros serviços necessários.

O site não configura headers Nginx em Pages. Condições e políticas do host:

- https://docs.github.com/en/pages/getting-started/getting-started-with-github-pages/about-github-pages
- https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site
- https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement
