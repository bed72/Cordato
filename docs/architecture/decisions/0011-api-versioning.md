# ADR 0011: API versioning

API versioning is path-based, applied once via `micronaut.server.context-path=/v1` — never a `/v1`
literal in code. Every server-built route is served under a single global `/v1` prefix, sourced from
that one property in `application.properties`. `@Controller` values stay version-relative (`/persons`,
`/authentication`), so the version is a config decision in one place, not scattered across controllers;
Micronaut's `@Version`/header negotiation is deliberately not used (it's for serving multiple versions
side by side, which isn't needed). Two consequences discovered empirically and worth remembering: (1) the
context-path is **global** and also prefixes the `micronaut.router.static-resources.*` mappings, so
Swagger UI and the raw OpenAPI doc are served under `/v1` too (`/v1/swagger-ui/**`, `/v1/swagger/**`; the
root paths 404) — there is no clean per-mapping opt-out, and docs-under-`/v1` was accepted as the
contract rather than hand-rolling a route to force them back to root; (2) the micronaut-openapi processor
reads the context-path at compile-time and **already bakes `/v1` into the generated paths**
(`/v1/persons/me`), so `OpenApiDefinition` declares **no `@Server(url = "/v1")`** — adding one would
double the prefix (`/v1/v1/...`). The in-context test `HttpClient` (`@Client("/")`) does not auto-prepend
the context-path, so end-to-end HTTP tests request the `/v1/...` paths explicitly.
