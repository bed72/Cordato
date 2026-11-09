# ADR-0006 — Secrets nativos Bruno e fallback CLI

- Status: Substituído por ADR-0008
- Data do registro: 2026-11-09
- Substitui: ADR-0005
- Escopo: credenciais, permissões, escopo de runtime e uso da interface Bruno

## Contexto

A coleção inicial foi validada pela CLI com variáveis de processo. Na interface
aberta diretamente, os placeholders de e-mail/senha não eram resolvidos e o script
de login interrompia o envio. A coleção precisa servir também ao uso manual sem
exigir iniciar a aplicação Bruno a partir de um terminal configurado.

## Decisão

Preservar Makefile, sandbox safe, isolamento dos ambientes e proteções do ADR-0005,
substituindo a estratégia de resolução exclusiva por processo:

- Declarar entradas privadas como Secrets nativos em cada ambiente `.bru`.
- Preencher valores na aba Secrets da interface; os arquivos guardam somente nomes,
  enquanto o Bruno mantém valores em seu armazenamento local protegido.
- Resolver o Secret do ambiente primeiro, com fallback para a variável de processo
  de mesmo significado e prefixo do ambiente na CLI. A CLI não acessa os Secrets
  criptografados da interface.
- Tratar também permissões e confirmação de production como Secrets configuráveis
  na interface. Valores locais não vazios prevalecem; `false` não herda `true` do processo.
- Manter entradas resolvidas em runtime, sem escrita no ambiente. Preservar sessão
  capturada no mesmo escopo, sem substituí-la pelo token inicial a cada requisição;
  descartar entradas/sessão ao trocar ambiente ou origem.
- Exibir identity/password parametrizados no body do login, mantendo a montagem
  por objeto para preservar corretamente os caracteres recebidos.

Login continua exclusivo de usuários verificados de `users`. Credenciais do
administrador/bootstrap não são reutilizadas, não há bypass de verificação ou MFA
e não são criadas contas para contornar a preparação do ambiente.

## Alternativas consideradas

- Exigir exportar variáveis e iniciar Bruno pelo terminal: mantém a fricção que
  motivou esta correção e não corresponde ao uso normal da interface.
- Gravar credenciais em variáveis comuns de `.bru`: expõe valores no Git.
- Ler o `.env` do servidor ou transferir sua senha para o login de users: mistura
  configuração de infraestrutura, superusuário e identidade da conta comum.
- Persistir token de login via `setEnvVar`: aumenta risco de vazamento e deixa
  sessões misturadas entre ambiente, origem e execuções.

## Consequências

- A interface exige apenas preencher os Secrets do ambiente e ter conta verificada;
  não depende de herdar o ambiente de um terminal.
- A CLI mantém os exemplos e comandos existentes com variáveis privadas por processo.
- Scripts podem resolver temporariamente valores em memória; não há promessa de
  ausência desses valores na inspeção local do cliente ou de revogação do JWT.
- Validação estática impede valores privados/placeholders de processo nos ambientes
  versionados. Testes de scripts cobrem o fluxo sem processo; E2E preserva a CLI.
- Não há teste visual da aplicação Bruno nem alteração de contas/dados existentes.

## Referências

- [Uso pela interface](../bruno/README.md#2-usar-pela-interface-bruno)
- [ADR-0005](0005-ferramentas-locais-e-colecao-bruno.md)
- [Secrets nativos Bruno](https://docs.usebruno.com/secrets-management/secret-variables)
