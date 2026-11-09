# ADR-0003 — Isolamento de testes por fronteira

- Status: Aceito
- Data do registro: 2026-11-09
- Natureza: registro retrospectivo de decisão adotada
- Escopo: organização, suporte e execução dos testes Go

## Contexto

O agrupamento antigo de compatibilidade misturava integração com o ciclo do
executável. Os testes HTTP do áudio também estavam junto da implementação,
apesar de inicializarem PocketBase. Precisamos distinguir essas fronteiras e
manter o código de produção limpo, sem perder cobertura ou duplicar preparação.

## Decisão

Manter unitários junto do código em `internal/`. Mover integração para
`tests/integration/`, espelhando `bootstrap` e `infrastructure/http/audio` e agrupando
APIs nativas em `pocketbase`. Separar E2E em `tests/e2e/server` e verificações de
dependências em `tests/architecture`.

Helpers compartilhados ficam em arquivos `.go` sob `tests/support/pocketbase`,
importáveis somente por testes. Fixtures e doubles locais ficam em arquivos
`*_test.go` próprios no pacote consumidor. Não criar dependências entre suítes.

Usar bancos e migrations temporários, dados sintéticos e capturador de e-mail.
A suíte padrão não abre portas; E2E é opcional via `CORDATO_HTTP_SMOKE=1`, somente
em loopback, com executável temporário e encerramento via SIGTERM. Cenários que
alteram ambiente, cwd ou migrations globais são sequenciais dentro do processo.

## Alternativas consideradas

- Manter tudo em `internal/compatibility`: nomes e localização não explicitariam
  a fronteira exercitada por cada teste.
- Mover também todos os unitários para `tests/`: afastaria testes simples da
  implementação sem necessidade, contrariando a convenção Go escolhida.
- Duplicar fixtures em integração e E2E: facilitaria divergência de preparação.
- Rodar E2E sempre: obrigaria a suíte padrão a compilar binário e abrir portas.

## Consequências

- É possível executar unitários, integração, arquitetura e E2E separadamente.
- A cobertura de autenticação, segurança, migrations e propriedade é preservada;
  somente cenários exclusivos da saúde customizada removida deixam de existir.
- Testes arquiteturais impedem imports de suporte na produção e dependências
  de integração/E2E nos unitários de `internal/`.
- Testes locais não comprovam TLS, SMTP real, Flutter, containers ou deploy.

## Referências

- [Organização e comandos](../tests/README.md)
- [Verificações arquiteturais](../tests/architecture/dependencies_test.go)
