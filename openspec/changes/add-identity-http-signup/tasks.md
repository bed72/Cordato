## 1. Build & runtime (non-behavioral chore)

- [x] 1.1 Add `implementation("io.micronaut:micronaut-http-server-netty")` to `build.gradle.kts` under the existing `micronaut-platform` BOM
- [x] 1.2 Verify a JSON body binder is on the classpath; add `micronaut-serde-jackson` (or `micronaut-jackson-databind`) explicitly only if the server artifact doesn't bring one transitively
- [x] 1.3 Add the Gradle `application` plugin and set the main class to `com.bed.cordato.main.MainKt` so `./gradlew run` serves HTTP
- [x] 1.4 Update `Main.kt` to start the embedded server (`io.micronaut.runtime.Micronaut.run(...)` or resolve the `EmbeddedServer` bean) while keeping the eager `DataSource` resolve that forces Flyway migrations at boot
- [x] 1.5 Confirm the project still builds: `./gradlew build`

## 2. HTTP request/response contract

- [x] 2.1 Create package `features/identity/infrastructure/http/` with `controllers/`, `requests/`, `responses/`, `errors/`, `mappers/`
- [x] 2.2 Add `SignUpRequest` (requests/) as a `data class` with non-null `String` fields `name`, `email`, `password` — structural shape only, no Bean-Validation annotations
- [x] 2.3 Add `PersonResponse` (responses/) exposing only `id`, `name`, `email` — no password/hash field exists on the type
- [x] 2.4 Add `ErrorResponse` (errors/) — a single shared neutral body (`message`, optional stable `code`) reused for every failure
- [x] 2.5 Add the error-mapping table from `SignUpError` to `(status, ErrorResponse)` (errors/): `InvalidEmail`/`InvalidName`/`WeakPassword`/`EmailAlreadyInUse` → 422; `WeakPassword` may expose `minLength`; `EmailAlreadyInUse` message is generic and never confirms registration

## 3. Mappers

- [x] 3.1 Add `internal fun SignUpRequest.toCommand(): SignUpCommand` (mappers/)
- [x] 3.2 Add `internal fun PersonEntity.toResponse(): PersonResponse` (mappers/), reading only id/name/email

## 4. Controller

- [x] 4.1 Add `PersonController` (controllers/) annotated `@Controller`, with `@Post("/sign-up")` consuming/producing JSON, taking `SignUpUseCase` via constructor injection
- [x] 4.2 In the handler: map body → `SignUpCommand`, invoke the use case, branch exhaustively over `SignUpResult` (no `@ExceptionHandler`), returning `201` + `PersonResponse` on success and the mapped status + `ErrorResponse` on each `SignUpError`
- [x] 4.3 Confirm Micronaut discovers the controller and injects the factory-provided `SignUpUseCase` (no new binding needed in `IdentityModule`)

## 5. Tests

- [x] 5.1 Add a controller test: successful signup returns `201` and a `PersonResponse` with no password/hash material
- [x] 5.2 Test structural validation: missing/non-JSON body and missing required field return `400` without invoking the use case
- [x] 5.3 Test each `SignUpError` mapping: `InvalidEmail`/`InvalidName`/`WeakPassword` → `422`; `WeakPassword` body may carry the min length
- [x] 5.4 Test the non-leak invariant: `EmailAlreadyInUse` returns a generic `422` body that does not echo the email or confirm registration
- [x] 5.5 Run `./gradlew test` — including the Konsist `ArchitectureTest` — and confirm green (infrastructure→application imports allowed; no sibling-context import; no HTTP import leaking into domain/application)

## 6. Reconcile & document

- [x] 6.1 Run `/opsx:sync` to fold the `identity-http-api` spec into `openspec/specs/`
- [x] 6.2 Note the documented exception in CLAUDE.md if warranted: `infrastructure/http/` controllers carry Micronaut routing annotations and are discovered directly (the one annotation-bearing exception to the annotation-free-adapter/`main/`-wiring rule)

## 7. Bean Validation at the edge (amendment — reverses design Decision 2)

- [x] 7.1 Add `micronaut-validation` (impl) + the validation KSP processor (pinned to the BOM-resolved version), KSP only — no kapt
- [x] 7.2 Expose the e-mail regex as a `const val EmailValueObject.PATTERN` (String) and build the value object's `Regex` from it — one definition for both the domain and the edge
- [x] 7.3 Annotate `SignUpRequest`: `@NotBlank` on name/email, `@Size(max = NameValueObject.MAX_LENGTH)` on name, `@Pattern(regexp = EmailValueObject.PATTERN)` on email, `@Size(min = PasswordValueObject.MIN_LENGTH)` on password (no `@NotBlank` on password — whitespace is a valid character)
- [x] 7.4 Add `@Validated` to `PersonController` and `@Valid` to the `@Body` parameter
- [x] 7.5 Add a `ConstraintViolationException` handler that returns `400` in the shared `ErrorResponse` shape (replaces Micronaut's default so the API keeps one error format)
- [x] 7.6 Update `PersonControllerTest`: blank name / over-max name / malformed e-mail / short password each return `400` (via `ErrorResponse`) without invoking the use case; success and `EmailAlreadyInUse` (valid-shape body) unchanged
- [x] 7.7 Update the CLAUDE.md HTTP note: request DTOs carry Bean Validation constraints that reference the domain value objects' constants/pattern (no literals); domain stays the single authority
