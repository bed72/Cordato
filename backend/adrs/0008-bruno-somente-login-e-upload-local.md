# ADR-0008 — Bruno somente com login e upload locais

- Status: Aceito por solicitação explícita
- Data do registro: 2026-11-09
- Substitui: ADR-0006 e ADR-0007
- Escopo: coleção Bruno e ferramentas locais, sem alteração do backend

## Contexto

O usuário solicitou remover a coleção abrangente e manter somente autenticação
e upload locais, com o ambiente preenchido, após dificuldades no desktop.

## Decisão

Manter somente login de users e upload binário. Sem produção, refresh, cadastro,
CRUD, permissões adicionais, login oculto ou helper de preparação de contas.
Restringir requests a loopback; token somente em memória, capturado pelo login.
O ambiente development é privado e ignorado, podendo ser preenchido localmente
em texto simples. O example versionado declara somente URL e nomes de Secrets.

## Alternativas consideradas

Manter a coleção com diagnóstico adicional ou exigir Secrets do desktop para
todo uso foi descartado em favor da simplificação solicitada.

## Consequências

O uso manual passa a ser login → seleção de arquivo → upload. O ambiente privado
não pode ser compartilhado ou versionado. Os testes Go de segurança das demais
APIs permanecem intactos. O E2E Bruno cobre exatamente as duas requests em banco
temporário; a CLI mantém apenas o workaround necessário para paths de upload.
Não autoriza deploy, mudanças de authRule ou leitura de outros arquivos privados.

## Referências

- [Coleção](../bruno/README.md)
- [ADR-0006](0006-secrets-nativos-bruno-e-fallback-cli.md)
- [ADR-0007](0007-requests-declarativas-e-pre-requisitos.md)
