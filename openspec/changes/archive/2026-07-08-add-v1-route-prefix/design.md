## Context

The HTTP surface today is three routes served at the root: `POST /authentication/sign-up`,
`POST /authentication/sign-in`, and `GET /persons/me`, plus the static Swagger UI (`/swagger-ui/**`) and
raw OpenAPI document (`/swagger/**`) declared as `micronaut.router.static-resources.*` mappings in
`application.properties`. Nothing carries a version marker. There is no external client yet, so path
churn is free now and expensive later. Micronaut offers a first-class global prefix,
`micronaut.server.context-path`, applied by the server to the routes it builds — no per-controller
change. The generated OpenAPI document (compile-time, KSP) currently emits paths straight from the
`@Controller` values (`/persons/me`), and the end-to-end tests drive those root paths through an
in-context `HttpClient`.

## Goals / Non-Goals

**Goals:**
- Serve every API route under a single global `/v1` prefix, configured in exactly one place.
- Keep `@Controller` paths version-relative (no `/v1` literal in code) so the prefix is a config concern.
- Keep Swagger UI and the raw OpenAPI document reachable (their location under `/v1` was accepted at
  apply time, since `context-path` prefixes static resources too — see Decisions).
- Keep the OpenAPI document self-consistent: its documented paths must resolve to the real routes, and
  "Try it out" must hit `/v1/...`.
- Keep the HTTP tests green against the versioned paths.

**Non-Goals:**
- No second version (`/v2`), no header/media-type version negotiation, no per-route/per-context prefix.
- No deprecation/sunset headers or version-discovery endpoint.
- No change to any controller/use-case/domain/persistence code — only config, OpenAPI metadata, tests.

## Decisions

**Decision: Path-based versioning via `micronaut.server.context-path=/v1`.**
One property in `application.properties` prefixes all server-built routes. Rationale: a URL segment is
visible, cacheable, browsable, and framework-native; the alternative — Micronaut's `@Version` +
`ApiVersion` header/media-type negotiation — is designed for *serving multiple versions side by side*,
which we explicitly don't need yet and which hides the version from a URL. A hand-rolled prefix on each
`@Controller` (`@Controller("/v1/persons")`) would scatter the decision across every controller and
couple code to the version string. Context-path centralizes it and leaves controllers version-relative.

**Decision: Static documentation resources move under `/v1` (resolved at apply time).**
Swagger UI and the OpenAPI JSON describe the API; the original intent was to pin them at `/swagger-ui` /
`/swagger` so their location stays stable across versions. Whether `context-path` *also* prefixes
`static-resources` mappings was the change's one open question (see Risks). **Verified empirically during
apply: it does** — `/v1/swagger-ui/` and `/v1/swagger/` serve `200`, the root paths `404`. Micronaut's
`context-path` is a single global prefix with no clean per-mapping opt-out, so the fallback resolved to
its all-or-nothing branch: **accept the docs under `/v1` and record that as the contract**. Docs living
under `/v1` alongside the API is coherent; the rejected alternative — a hand-rolled programmatic route or
filter to re-serve docs at root — is exactly the un-clean workaround this fallback was written to avoid.

**Decision: Do NOT declare a `/v1` server URL on the OpenAPI document (revised at apply time).**
The original plan assumed the KSP processor would emit context-relative paths (`/persons/me`) and that a
`@Server(url = "/v1")` would supply the prefix. **That assumption proved false on apply:** the
micronaut-openapi processor reads `micronaut.server.context-path` at compile-time and already bakes `/v1`
into every documented path (`/v1/persons/me`). Adding a server URL on top would make Swagger UI resolve
`/v1` + `/v1/persons/me` = `/v1/v1/persons/me` (a 404). So **no `@Server` is declared**: the document is
self-consistent against the default `/` server, "Try it out" hits the real `/v1/...` route, and the
version stays sourced from exactly one place (the context-path). A doc comment on `OpenApiDefinition`
records this.

**Decision: Endpoint paths in feature specs are version-relative.**
Rather than edit every `/persons/me`-style path in `identity-http-api` (and future feature specs), the
`api-versioning` capability states once that documented endpoint paths are relative to the active
version prefix. This keeps the cross-cutting rule in one spec and avoids churn/drift across sibling
specs each time the prefix changes.

## Risks / Trade-offs

- **Context-path may or may not capture `static-resources` mappings (version-dependent).** → *Mitigation*:
  verify empirically during apply by hitting `/swagger-ui` and `/v1/swagger-ui`; apply the fallback above
  based on what's observed. This is the change's single real unknown and is called out as an open question.
- **The in-context test `HttpClient` (`@Client("/")`) does not auto-prepend the context-path for absolute
  request paths.** → *Mitigation*: update the test requests to `/v1/...` explicitly. This is expected and
  is part of the change's task list, not a surprise.
- **Breaking the public path contract.** → *Mitigation*: no external consumer exists yet; doing it now is
  precisely why. Low rollback cost — remove the one property and revert the OpenAPI server + test paths.
- **Management/health endpoints (if added later) also sit behind context-path.** Not in scope today (no
  management endpoints exist); noted so a future health-check change knows the prefix applies.

## Migration Plan

1. Add `micronaut.server.context-path=/v1` to `application.properties`.
2. Leave the `@OpenAPIDefinition` without a server URL — the processor already prefixes the paths (a
   `/v1` server would double it). A doc comment records why.
3. Boot the app (or run the HTTP tests) and probe: confirm `/v1/persons/me` etc. resolve, confirm the
   Swagger UI/JSON location. Result: docs moved under `/v1`; accepted as the contract.
4. Update `PersonControllerTest`, `AuthenticationControllerTest`, and the edge-auth probe tests to the
   `/v1` paths; `./gradlew build` green.
5. Record the decision in `CLAUDE.md`; `/opsx:sync` the `api-versioning` spec; archive.

Rollback: revert the property, the OpenAPI server entry, and the test path edits — no persisted state.

## Open Questions

- ~~Does `micronaut.server.context-path` prefix the `micronaut.router.static-resources.*` mappings on the
  pinned Micronaut 4.10.x line?~~ **Resolved (apply):** yes — it prefixes them, and there is no clean
  per-mapping opt-out. The static-resource fallback's all-or-nothing branch was taken: docs are served
  under `/v1`. A second, related finding surfaced at the same time: the micronaut-openapi processor also
  reads `context-path` and prefixes the *documented* paths, so the planned `/v1` server URL was dropped to
  avoid a doubled prefix.
