# Publicação estática sem VPS

O artefato é a própria pasta **`site/public/`**. Não existe build, API, banco,
instalação npm ou servidor de aplicação. Não publique o restante do repositório.

## GitHub Pages

1. Confirme a elegibilidade do repositório: GitHub Free exige repositório público;
   repositório privado exige plano compatível. Não altere a visibilidade sem
   autorização e revisão de arquivos e histórico para dados sensíveis.
2. Em **Settings → Pages**, escolha **GitHub Actions** como fonte.
3. Configure e verifique o domínio personalizado `app.cordato.cloud`.
4. No DNS, configure `app` como CNAME para `bed72.github.io`, confirmando que essa
   é a conta publicadora. Preserve os valores anteriores para reversão e revise
   conflitos antes de mudar. Não altere domínio raiz ou outros subdomínios.
5. Depois dos commits na `main` e verificações do site aprovadas, execute
   **Actions → Publish site to GitHub Pages → Run workflow**.
6. Aguarde DNS/certificado e habilite **Enforce HTTPS**.
7. Valide as quatro páginas, acesso direto, refresh, teclado e mobile antes de
   desativar a hospedagem anterior.

Workflow:
[`../../.github/workflows/site-pages.yml`](../../.github/workflows/site-pages.yml).
É manual, limitado à `main`, com ambiente `github-pages`. Faz upload direto de
`site/public` e não executa Node, npm ou compilação do projeto.
Adicioná-lo ao código não publica ou configura domínio/DNS.

O endereço de projeto `bed72.github.io/Cordato/` não é suportado pelos caminhos
absolutos atuais. Use o domínio próprio para servir na raiz. Para dispensar
também a renovação do domínio, um site de usuário em `bed72.github.io` permitiria
a raiz gratuita, mas criar/substituir esse repositório exige decisão separada.

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
URLs limpas e refresh sem fallback SPA. `/privacy` pode redirecionar para
`/privacy/`; confira o endereço HTTPS final informado à Google Play.
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
