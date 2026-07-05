## 1. Shape compartilhado no core

- [x] 1.1 Criar o pacote `core/infrastructure/http/errors/`
- [x] 1.2 Mover `ErrorResponse` de `identity/infrastructure/http/errors/` para `core/infrastructure/http/errors/`, adicionando o campo `errors: List<FieldError> = emptyList()` (mantendo `code` e `message`); atualizar o KDoc para o contrato compartilhado
- [x] 1.3 Adicionar `FieldError` (`@Serdeable data class` com `field: String`, `message: String`) em `core/infrastructure/http/errors/`

## 2. Handlers genéricos no core

- [x] 2.1 Mover `ConstraintViolationExceptionHandler` para `core/infrastructure/http/errors/` e reescrevê-lo para emitir um `FieldError` por violação (derivar `field` do nó final do `propertyPath`, `message` = texto curado), com `code = "INVALID_REQUEST"` e uma `message` de resumo genérica — sem concatenar
- [x] 2.2 Adicionar o handler de corpo malformado/ausente: interceptar a exceção de parse/bind de corpo do Micronaut → `400` no `ErrorResponse` compartilhado, `errors` vazia, mensagem genérica (confirmar o tipo exato por teste — ver 5.2). Confirmado por probe: JSON inválido = `io.micronaut.json.JsonSyntaxException` (replace `JsonExceptionHandler`); corpo ausente = `UnsatisfiedRouteException` (replace `UnsatisfiedRouteHandler`) — dois handlers, mesmo shape
- [x] 2.3 Adicionar o fallback `ExceptionHandler<Throwable>` → `500` com `code = "INTERNAL_ERROR"` e `message` genérica fixa; logar a exceção (stacktrace) e nunca serializar `exception.message`

## 3. Repontar identity

- [x] 3.1 Remover `ErrorResponse` e `ConstraintViolationExceptionHandler` de `identity/infrastructure/http/errors/`
- [x] 3.2 Atualizar `SignUpErrorResponseMapper` para importar `ErrorResponse` de `core`; confirmar que `EmailAlreadyInUse` continua escalar (`message` genérica, sem `FieldError`) e que o `422` não muda

## 4. Testes

- [x] 4.1 Testes de unidade do `ConstraintViolationExceptionHandler` em `core`: violação de um campo → um `FieldError`; violações de N campos → N itens (sem concatenar); `field` é o nó final (ex.: `email`), não o caminho interno
- [x] 4.2 Teste do fallback `Throwable` → `500` com corpo neutro; asserir que o corpo não contém `exception.message` nem stacktrace
- [x] 4.3 Atualizar `PersonControllerTest`: corpo com múltiplos campos inválidos → `400` com um item por campo em `errors`; JSON inválido e corpo vazio → `400` no shape compartilhado; sucesso e `EmailAlreadyInUse` inalterados
- [x] 4.4 Confirmar o alvo do handler de corpo malformado por teste de endpoint (JSON quebrado e corpo vazio caem no `400`, não no `500`)

## 5. Verificação

- [x] 5.1 Rodar `./gradlew build` (inclui o Konsist `ArchitectureTest`): `core` não importa `features/*`; `domain`/`application` não importam Micronaut/HTTP — passa; a única falha é `PersistencePersonRepositoryTest`, bloqueado por ambiente (Testcontainers sem Docker), alheio a esta mudança
- [x] 5.2 Rodar o app (`make db-up` + `./gradlew run`) e exercer os quatro caminhos (`201`, `400` multi-campo, `422`, `500`) confirmando o mesmo shape `ErrorResponse` — VERIFICADO end-to-end: `201` (corpo sem hash), `422 SIGNUP_REJECTED` (email já em uso, neutro), `400 INVALID_REQUEST` (um `FieldErrorResponse` por campo), `400 MALFORMED_REQUEST` (JSON inválido), e `500 INTERNAL_ERROR` neutro (banco derrubado no meio da request). Achado colateral: o app roda com SLF4J NOP (sem backend de log), então o detalhe do `500` não é logado no servidor — a metade "detalhe fica só no log" da invariante não acontece em runtime até adicionar um binding (ex.: `logback-classic`)

## 6. Reconciliar & documentar

- [x] 6.1 Rodar `/opsx:sync` para foldar `http-error-handling` (nova) e `identity-http-api` (modificada) em `openspec/specs/`
- [x] 6.2 Atualizar o CLAUDE.md: o contrato de erro HTTP (`ErrorResponse`/`FieldError` + handlers) mora em `core/infrastructure/http/`; os `ExceptionHandler` são annotation-bearing descobertos direto (mesma exceção dos controllers); `422` de domínio segue fail-fast e `EmailAlreadyInUse` nunca vira `FieldError`
