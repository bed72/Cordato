## Why

Every HTTP route today is served at the root (`/persons/me`, `/authentication/sign-in`, …), with no
version marker. Committing to an explicit version prefix now — while there are only three routes and no
external client depends on the paths — lets the API evolve breaking changes behind `/v2` later without
disrupting `/v1` consumers. Adding it after clients integrate would itself be the breaking change we
want to avoid.

## What Changes

- **BREAKING** (public HTTP contract): every API route moves under a global `/v1` prefix
  (`/persons/me` → `/v1/persons/me`, `/authentication/sign-up|sign-in` → `/v1/authentication/...`). The
  prefix is applied once, globally, via Micronaut's `micronaut.server.context-path=/v1` — no
  `@Controller` annotation changes, so a route's path stays version-relative in code.
- Path-based versioning is the chosen strategy (a URL segment, not a header or media-type parameter):
  it is visible, cacheable, and trivially browsable in Swagger UI.
- **Static documentation resources move under the prefix too**: `micronaut.server.context-path` is a
  global prefix that also captures the `static-resources` mappings, with no clean per-mapping opt-out, so
  Swagger UI and the raw OpenAPI document are served at `/v1/swagger-ui/**` and `/v1/swagger/**` (root
  paths 404). This was the change's one open question, resolved empirically at apply time; docs living
  under `/v1` alongside the API is coherent and was accepted as the contract (an all-or-nothing call,
  deliberate — the alternative was a hand-rolled route to force docs back to root, which the design
  flagged to avoid).
- The generated OpenAPI document needs **no `/v1` server URL**: the micronaut-openapi processor reads
  `context-path` at compile-time and already bakes `/v1` into every documented path (`/v1/persons/me`), so
  the document is self-consistent against the default `/` server and "Try it out" hits the real route.
  Adding a server entry on top would double the prefix.
- The end-to-end HTTP tests are updated to drive the versioned paths (`/v1/persons/me`, etc.).

Explicitly **out of scope**: any second version (`/v2`), header/media-type negotiation, per-route or
per-context version overrides, and deprecation/sunset signalling. This change establishes exactly one
prefix applied uniformly; a multi-version strategy is a later change if and when it's needed.

## Capabilities

### New Capabilities
- `api-versioning`: the cross-cutting rule that every API route is exposed under a single global
  version prefix (`/v1`) via the server context-path, that the context-path also captures the static
  documentation resources (Swagger UI / OpenAPI doc served under `/v1`), that the generated OpenAPI
  document carries the `/v1` prefix in its paths (processor-applied, no server URL), and that endpoint
  paths documented in feature specs are henceforth relative to that prefix.

### Modified Capabilities
<!-- None. `identity-http-api`'s documented endpoint paths become version-relative by the api-versioning
     convention (no per-path spec edit), and `openapi-documentation` is unchanged — Swagger UI stays
     unprefixed; the new `/v1` server-URL declaration is owned by the api-versioning capability as a
     direct consequence of versioning, not a change to how the doc is generated. -->

## Impact

- **Config**: `src/main/resources/application.properties` — add `micronaut.server.context-path=/v1`.
  Verified empirically at apply time that this prefix **also** captures the existing
  `micronaut.router.static-resources.*` mappings (`/swagger`, `/swagger-ui`), so the docs move under
  `/v1` (see design.md — the open question resolved to the all-or-nothing fallback).
- **OpenAPI**: `core/infrastructure/http/openapi/` — **no** `@Server` added; a doc comment on
  `OpenApiDefinition` records that the processor already bakes `/v1` into the paths, so a server URL would
  double the prefix.
- **Tests**: `PersonControllerTest`, `AuthenticationControllerTest`, and the `AuthenticationProbeController`-driven
  edge-auth tests update their request paths to `/v1/...`. No production controller/use-case/domain code
  changes.
- **Docs**: `CLAUDE.md` gains a short note recording the path-based `/v1` versioning decision, the
  processor auto-prefix (no server URL), and that Swagger docs live under `/v1` too.
- **Dependencies**: none added or removed.
