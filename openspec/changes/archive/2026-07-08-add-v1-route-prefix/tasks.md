## 1. Apply the global version prefix

- [x] 1.1 Add `micronaut.server.context-path=/v1` to `src/main/resources/application.properties`, with a short comment recording the path-based versioning decision.
- [x] 1.2 Confirm the `@Controller` values stay version-relative (no `/v1` literal added anywhere in code).

## 2. Reconcile the OpenAPI document

- [x] 2.1 ~~Add a `/v1` server to the `@OpenAPIDefinition`.~~ **Superseded on apply:** the micronaut-openapi processor reads `micronaut.server.context-path` at compile-time and already bakes `/v1` into every documented path (`/v1/persons/me`). A `@Server(url = "/v1")` on top would double the prefix (`/v1` + `/v1/persons/me`), so **no server entry is declared** — the version is sourced once, from the context-path. A doc comment on `OpenApiDefinition` records why.
- [x] 2.2 Rebuilt and confirmed the generated OpenAPI document under `META-INF/swagger` lists **no `servers:` entry** (defaults to `/`) and emits `/v1`-prefixed paths (`/v1/persons/me`), so Swagger UI's "Try it out" resolves to the real route without doubling.

## 3. Verify Swagger/static-resource location (the one open question)

- [x] 3.1 Probed via a throwaway `@MicronautTest` (booting the server) hitting root vs `/v1` doc paths. **Result: `context-path` DID prefix the `static-resources` mappings** — `/v1/swagger-ui/` and `/v1/swagger/` return `200`; the root `/swagger-ui/` and `/swagger/` return `404`.
- [x] 3.2 The docs moved under `/v1`. Micronaut's `context-path` is global with no clean per-mapping opt-out, so the design's fallback resolved to the **all-or-nothing branch: `/v1`-prefixed docs are the recorded contract** (deliberate, user-confirmed). No workaround code added — proposal/spec/design updated to record that docs live under the version prefix alongside the API.

## 4. Update the HTTP tests

- [x] 4.1 Update `PersonControllerTest` request paths to `/v1/persons/me`.
- [x] 4.2 Update `AuthenticationControllerTest` request paths to `/v1/authentication/sign-up` and `/v1/authentication/sign-in`.
- [x] 4.3 Update the edge-auth tests driven through `AuthenticationProbeController` (the `@Authenticated`/open probe routes) to the `/v1` paths.
- [x] 4.4 Run `./gradlew build` — Konsist + all HTTP/unit/integration tests green against the versioned paths.

## 5. Reconcile docs (post-implementation)

- [x] 5.1 Add a short note to `CLAUDE.md` recording the path-based `/v1` versioning decision, the single-origin `context-path` config, controllers staying version-relative, the OpenAPI-processor auto-prefix (no `@Server`), and that Swagger docs live under `/v1` too.
- [x] 5.2 Run `/opsx:sync` to fold the `api-versioning` spec into `openspec/specs/`.
