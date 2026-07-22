## 1. Envelope de sucesso e erro no `core`

- [x] 1.1 Criar `DataResponse<T>(data: T, meta: MetaResponse? = null, links: LinksResponse? = null)`,
      `MetaResponse(pagination: PaginationMetaResponse? = null)`, `PaginationMetaResponse(nextCursor:
      String?)` e `LinksResponse(self: String, next: String? = null)` em
      `core/infrastructure/http/responses/`.
- [x] 1.2 Criar `ErrorsResponse(errors: List<ErrorItemResponse>)`, `ErrorItemResponse(status: String, code:
      String, message: String, source: ErrorSourceResponse? = null)` e `ErrorSourceResponse(field: String)`
      em `core/infrastructure/http/responses/`, substituindo `ErrorResponse`/`FieldErrorResponse`.
- [x] 1.3 Criar `DataResponses.kt` com os builders `ok(item: T, meta: MetaResponse? = null, links:
      LinksResponse? = null): HttpResponse<DataResponse<T>>` e `created(item: T): HttpResponse<DataResponse<T>>`.
- [x] 1.4 Reescrever `ErrorResponses.kt` (`badRequest`, `unauthorized`, `unprocessable`, `internalError`)
      para montar `ErrorsResponse` com um único `ErrorItemResponse` (sem `source`) nos casos escalares,
      mantendo as assinaturas públicas dos builders.
- [x] 1.5 Remover `ErrorResponse.kt` e `FieldErrorResponse.kt` (substituídos pelo 1.2).
- [x] 1.6 Testes unitários dos novos builders (`support`/`factories` conforme a skill `writing-tests`):
      `ok`/`created` produzem `DataResponse` correto com/sem `meta`/`links`; `badRequest` com múltiplos
      `FieldErrorResponse` de entrada produz um `ErrorItemResponse` por campo com `source.field`;
      `unauthorized`/`unprocessable`/`internalError` produzem exatamente um item sem `source`.

## 2. Handler de validação de borda

- [x] 2.1 Atualizar o `ExceptionHandler` de `ConstraintViolationException` em
      `core/infrastructure/http/errors/handlers/` para montar `List<ErrorItemResponse>` (um item por campo
      violado, `status = "400"`, `code = "INVALID_REQUEST"`, `source.field`) em vez de
      `List<FieldErrorResponse>`.
- [x] 2.2 Atualizar/portar os testes existentes em `core/infrastructure/http/errors/handlers/` para o novo
      shape: violação de um campo → um item; violações de múltiplos campos → um item por campo, cada um com
      `source.field` correto e sem mensagens concatenadas.

## 3. Migrar `identity` para o envelope

- [x] 3.1 Atualizar `PersonResponseMapper`/`SignInResponseMapper` se necessário (o formato interno de
      `PersonResponse`/`SignInResponse` não muda — só como o controller os envelopa).
- [x] 3.2 Atualizar `AuthenticationController` (`POST /sign-up`, `POST /sign-in`) para responder via os
      builders `created`/`ok` do 1.3, envelopando em `data`.
- [x] 3.3 Atualizar `PersonController` (`GET /persons/me`, `PATCH /persons/me/name`, `PATCH
      /persons/me/email`, `PATCH /persons/me/password`) para responder via `ok` do 1.3, envelopando em
      `data`.
- [x] 3.4 Atualizar `SignUpErrorResponseMapper`, `SignInErrorResponseMapper`, `MeErrorResponseMapper`,
      `UpdateNameErrorResponseMapper`, `UpdateEmailErrorResponseMapper`, `UpdatePasswordErrorResponseMapper`
      se a assinatura de retorno mudar de tipo (`HttpResponse<ErrorResponse>` → `HttpResponse<ErrorsResponse>`).
- [x] 3.5 Atualizar `AuthenticationControllerDoc` e `PersonControllerDoc` para declarar os schemas
      `DataResponse`/`ErrorsResponse` nas anotações `@ApiResponse`.
- [x] 3.6 Atualizar `AuthenticationControllerTest`, `PersonControllerTest`,
      `PersonUpdateNameControllerTest`, `PersonUpdateEmailControllerTest`,
      `PersonUpdatePasswordControllerTest` para os novos asserts: sucesso lê `data.<campo>` em vez do corpo
      cru; erro lê `errors[0]` (ou `errors[N]` por campo) em vez do `ErrorResponse` único. Preservar todos os
      casos de não-vazamento já cobertos (conflito de e-mail, 401 indistinguível entre causas).

## 4. Migrar `expense` para o envelope

- [x] 4.1 Simplificar `ExpenseResponseMapper.toResponse()` (o método sobre `ExpensePageVirtualObject`) para
      devolver `List<ExpenseResponse>` em vez de `ExpensePageResponse`.
- [x] 4.2 Remover `ExpensePageResponse.kt`.
- [x] 4.3 Atualizar `ExpenseController.create` para responder via `created` do 1.3 (envelopando o gasto em
      `data`).
- [x] 4.4 Atualizar `ExpenseController.page`/`list` para compor `meta`/`links` (o `next_cursor` codificado
      em `meta.pagination`, `links.self` a partir da rota atual, `links.next` só quando há próxima página) e
      responder via `ok` do 1.3 com `data` como a lista de itens.
- [x] 4.5 Atualizar `CreateExpenseErrorResponseMapper` se a assinatura de retorno mudar de tipo.
- [x] 4.6 Atualizar `ExpenseControllerDoc` para declarar os schemas `DataResponse`/`ErrorsResponse`
      (incluindo `meta`/`links` no corpo de sucesso de `GET /expenses`).
- [x] 4.7 Atualizar `ExpenseControllerTest` para os novos asserts: sucesso lê `data`/`meta.pagination`/`links`
      em vez de `ExpensePageResponse`; erro lê `errors[...]`. Cobrir explicitamente: página vazia (sem
      `meta.pagination`, `links.next` nulo), página com continuação (`meta.pagination.next_cursor` e
      `links.next` presentes), última página (`links.next` nulo), e violação de múltiplos campos em `POST
      /expenses` (um item de `errors` por campo).

## 5. Documentação arquitetural

- [x] 5.1 Escrever a ADR que substitui a 0008 em `docs/architecture/decisions/`, documentando o novo shape
      (`DataResponse`/`ErrorsResponse`) e referenciando explicitamente que os invariantes de não-vazamento
      da 0008 permanecem — só a casca estrutural muda.
- [x] 5.2 Atualizar o índice `docs/architecture/decisions/README.md`.

## 6. Fechamento

- [x] 6.1 Rodar `./gradlew build` (compila, roda o Konsist `ArchitectureTest`, gera o OpenAPI) e confirmar
      que o spec gerado reflete `DataResponse`/`ErrorsResponse` em toda rota.
- [x] 6.2 Rodar `./gradlew test` completo e confirmar verde.
- [x] 6.3 Rodar `/opsx:sync` para reconciliar `http-response-envelope` (nova), `http-error-handling`,
      `expense-http-api`, `identity-http-api` com os specs principais.
- [x] 6.4 Rodar `/opsx:archive` para arquivar a change.
