## Why

O guard de autenticação de borda já resolve um Bearer vivo num `AuthenticatedActor` (o `personId`), mas
nenhuma rota protegida consome esse ator ainda — não há como um cliente autenticado recuperar os próprios
dados. `GET /persons/me` é a primeira rota protegida de verdade: fecha o ciclo aberto pelo sign-in (mint da
sessão) exercitando o lado consumidor (o filtro + o binder) e devolve a visão pública da pessoa dona da
sessão.

## What Changes

- Nova operação de aplicação **`Me`** em `identity`: `MeUseCase(MeCommand(personId)) -> MeResult`, que
  resolve a pessoa **ativa** dona da sessão e devolve sua visão pública, como um `sealed` result
  (`Success(person)` / `Failure(MeError.PersonNotFound)`), sem exceções.
- Nova rota HTTP protegida **`GET /persons/me`** num `PersonController` novo (separado do
  `AuthenticationController`, que guarda apenas os fluxos abertos de mint), marcada `@Authenticated` e
  consumindo o `AuthenticatedActor` injetado pelo binder do core. Reutiliza `PersonResponse` /
  `PersonEntity.toResponse()` (sem material de senha).
- Sessão viva cuja pessoa não está mais ativa (corrida com deleção de conta) **colapsa no `401` neutro
  compartilhado** (code `UNAUTHENTICATED`, mesma chave i18n `error.authentication.message`) — indistinguível
  de token ausente/expirado. Nenhuma chave i18n nova.
- Novo método de consulta no `PersonRepository`: `findById(id)` que retorna a pessoa **apenas quando ativa**
  (espelha a neutralidade do `findByEmail`), implementado no adapter jOOQ.
- Documentação OpenAPI da rota num `PersonControllerDoc` (200/401/500) e um **security scheme Bearer**
  global no `OpenApiDefinition`, com a operação protegida marcada, para o lock aparecer no Swagger UI.

## Capabilities

### New Capabilities
- `person-profile`: recuperação, pela própria pessoa autenticada, da sua visão pública (id/nome/e-mail) a
  partir da sessão viva — a operação `Me` de domínio/aplicação e sua resolução por id ativo, com o
  tratamento de sessão órfã.

### Modified Capabilities
- `identity-http-api`: adiciona a rota protegida `GET /persons/me` — binding do ator autenticado, delegação
  ao `MeUseCase`, mapeamento `Success -> 200 PersonResponse` e sessão órfã `-> 401` neutro; sem corpo/validação.
- `identity-persistence`: adiciona a consulta `findById` (somente pessoa ativa) ao `PersonRepository` e seu
  adapter durável.
- `openapi-documentation`: declara um security scheme HTTP Bearer no documento e marca operações protegidas,
  para que rotas `@Authenticated` exponham o requisito de autenticação no Swagger UI.

## Impact

- **Novo código**: `identity/application` (`MeCommand`, `MeResult`, `MeError`, `MeUseCase`),
  `identity/infrastructure/http` (`PersonController` + `docs/PersonControllerDoc`, `mappers/errors` do
  `MeError`), wiring no `IdentityFactory`.
- **Alterado**: `PersonRepository` (+`findById`), `PersistencePersonRepository`, `OpenApiDefinition`
  (+`@SecurityScheme`), fake de teste `FakePersonRepository`.
- **Reuso (sem alteração)**: `AuthenticatedActor`/`Authenticated`/`AuthenticatedFilter`/binder do core,
  `PersonResponse` + `toResponse`, builder `unauthorized`, chave i18n `error.authentication.message`.
- **Sem migração de banco, sem dependência nova, sem mudança de contrato de erro.**
