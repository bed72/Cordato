# ADR-0002 — Arquitetura proporcional e composição manual

- Status: Aceito
- Data do registro: 2026-11-09
- Natureza: registro retrospectivo de decisão adotada
- Escopo: application, infrastructure, bootstrap e nomenclatura

## Contexto

O backend possui uma operação própria pequena: validar o aceite de bytes de áudio.
As demais capacidades são nativas do PocketBase. A separação deve permitir testar
regras sem HTTP ou SDK, sem reproduzir uma estrutura maior que o comportamento.

## Decisão

Separar `internal/application/audio/`, `internal/infrastructure/http/audio/` e
`internal/bootstrap/`. O bootstrap é o composition root, não um client de infra;
`cmd/cordato/main.go` permanece como entrada do processo.

O handler depende de application; sua interface consumidora `Acceptor` exige apenas
`Execute(audio.Input) error`. A composição injeta a implementação concreta.
Application usa tipos próprios e não importa PocketBase, HTTP ou persistência.

O único caso de uso do pacote se chama `UseCase`, em `usecase.go`, acompanhado
de `usecase_test.go`. O nome completo é `audio.UseCase`. Operações futuras distintas
receberão nomes específicos com sufixo `UseCase`, sem concentrar responsabilidades.

Não criar domínio, ports, repositories, adapters ou framework de DI sem necessidade
concreta. CRUD nativo não recebe camadas de repasse. A saúde customizada da POC
é removida; a saúde nativa continua disponível.

## Alternativas consideradas

- Handler contendo todas as regras: impediria exercitar o contrato de aceite
  independentemente de HTTP/PocketBase.
- Copiar integralmente a árvore de Clean Architecture do tutorial: criaria pacotes
  e interfaces vazias sem reduzir acoplamento real.
- Usar `internal/main`: confundiria a composição importável com o pacote executável Go.
- Manter `Accept` como nome do tipo: não explicitaria o papel de caso de uso desejado.
- Usar `AcceptUseCase` enquanto há uma única operação no pacote: válido, mas o nome
  contextualizado `audio.UseCase` atende à convenção escolhida com menos repetição.

## Consequências

- O contrato de aplicação é testável sem servidor ou banco.
- Frameworks e transporte ficam nas fronteiras externas; a montagem é explícita.
- Novas abstrações precisam justificar a responsabilidade e o acoplamento removido.
- Não existe repository de áudio, pois não há persistência nesta etapa.

## Referências

- [Arquitetura Go](../ARCHITECTURE.md#composição-e-dependências)
- [Caso de uso](../internal/application/audio/usecase.go)
- [Handler HTTP](../internal/infrastructure/http/audio/handler.go)
- [Clean Architecture em Go](https://golang.com.br/tutoriais/go-clean-architecture/)
