---
name: http-slice
description: Build or edit a bounded context's HTTP slice in Cordato — controller + <Controller>Doc, @Serdeable request/response DTOs, the per-context error mapper, the shared core error contract (400/422/500), i18n-by-key, and compile-time OpenAPI. Use when adding or changing any controller, endpoint, request/response DTO, error mapper, HTTP error handler, message key, or OpenAPI doc.
metadata:
  author: cordato
  version: "1.0"
---

Reinforces the HTTP conventions in `CLAUDE.md`. This skill is about *how the HTTP edge is shaped and named* — it does **not** authorize new behavior. A new endpoint that adds/changes domain behavior still needs an approved OpenSpec change first (`/opsx:propose` → `/opsx:apply`). Wiring an HTTP slice over an already-specified use case is non-behavioral plumbing and does not.

## Before writing anything

1. Open the **reference slice** and mirror it exactly — don't invent a shape:
   - `features/identity/infrastructure/http/` (controller, `docs/`, `requests/`, `responses/`, `mappers/`)
   - `core/infrastructure/http/` (the shared error contract) and `core/infrastructure/i18n/`
   - `src/main/resources/i18n/messages.properties` (the one message bundle)
2. Read `features/<context>/README.md` for the business rules the endpoint serves.

## Where each piece goes

| Put it in… | What it is | Notes |
|---|---|---|
| `features/<ctx>/infrastructure/http/controllers/` | `@Controller` (driving/inbound adapter) | the **one** annotation-bearing adapter discovered directly (not via `@Factory`); depends only on the pure use case |
| `…/http/controllers/docs/<Controller>Doc.kt` | interface holding all OpenAPI annotations | controller `implements` it; Micronaut inherits the metadata onto the method |
| `…/http/requests/` | `@Serdeable` request DTO | carries edge Bean Validation |
| `…/http/responses/` | `@Serdeable` response DTO | never leaks password material |
| `…/http/mappers/` | `toCommand` / `toResponse` extension fns + the context's `<X>ErrorResponseMapper` | `internal` extension functions, per the mapper convention |
| `core/infrastructure/http/responses/` | shared `ErrorResponse`/`FieldErrorResponse` DTOs + `badRequest`/`unprocessable`/`internalError` builders | body shape lives here, nothing builds it inline |
| `core/infrastructure/http/errors/handlers/` | generic `ExceptionHandler`s (400/500) | discovered by exception type; **not** wired in `CoreFactory` |
| `src/main/resources/i18n/messages.properties` | every human-readable message, by key | add a key here, never inline text |

## Hard rules

- **Controller stays thin**: only routing/validation (`@Controller`/`@Post`/`@Validated`/`@Body`/`@Valid`) + delegation to the use case + branching the sealed `*Result`. No business logic, no inline error bodies. Annotate the success method `@Status(HttpStatus.CREATED)` (etc.) so OpenAPI documents the right success code even though it returns `HttpResponse<*>`.
- **OpenAPI lives on `<Controller>Doc`, never on the controller.** Body schemas via `@ApiResponse` + `@Content(schema = @Schema(implementation = …))`; field-level `@Schema(description, example)` on the DTOs. The Doc interface is a documentation artefact of infrastructure — it never duplicates the use case signature nor becomes an application port.
- **Validation has one origin, runs in two places.** The DTO's `@NotBlank`/`@Size`/`@Pattern` give early per-field `400`s; the domain value object stays the unbypassable authority. Every edge constraint that mirrors a domain rule **references the value object's own `const`/`PATTERN`** (`@Size(max = NameValueObject.MAX_LENGTH)`, `@Pattern(regexp = EmailValueObject.PATTERN)`) — never a copied literal. A pure-transport field (paging/filter, no value object) is validated only at the edge.
- **Every message is `{key}` into the bundle** — constraint `message = "{signup.request.name.notBlank}"`, policy text via `messages.resolve("signup.error.…")`. The error **`code`** (`INVALID_NAME`, `MALFORMED_REQUEST`, …) stays an inline constant — it's the machine contract, never localized. Bounds (`max`/`min`/`regexp`) still reference the value objects' constants so the edge can't drift.
- **The error contract is fixed and shared:** malformed/edge → `400`, well-formed-but-domain-rejected → `422`, unexpected → `500` (detail logged only, never serialized). The feature error mapper owns the *policy* (which error → code/message); core's `unprocessable`/`badRequest`/`internalError` builders own the *shape*. A domain rejection is a single **scalar** `422` (no per-field `errors`).

## The non-leak invariant (identity, and any context that authenticates)

- Never turn an existence/credential conflict into a `FieldErrorResponse(field = …)` — that's an account-discovery oracle. `EmailAlreadyInUse` → generic scalar `422` (`SIGNUP_REJECTED` + a message that never confirms the e-mail is registered).
- **The status code is part of the invariant too.** All of a context's domain rejections share one status (`422`). Never give one error a distinct status (`409`/`400`) while its siblings stay `422` — the odd-status-out leaks exactly what the generic body hides. A rule-specific status is only ever acceptable applied uniformly to *every* domain rejection at once (a contract-wide decision, needs a spec), and even then `422` beats `400` since the payload is syntactically valid.

## Finish

- Add tests per the **writing-tests** skill — `PersonControllerTest` is the worked HTTP example.
- Run `./gradlew test` — `ArchitectureTest` (Konsist) fails the build on a layering violation (e.g. a controller reaching past its use case, or `application`/`domain` importing Micronaut).
- Drive the endpoint once (`make db-up` then `./gradlew run`, or the `/verify` skill) — a green build doesn't prove the route answers.
