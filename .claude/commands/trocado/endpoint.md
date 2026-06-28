---
name: "Trocado: Endpoint"
description: Expose an existing use case over HTTP the spec-first way — ensure an OpenSpec change exists, scaffold the Litestar edge (controller + DTOs + mappers + router wiring + error map), then guard it.
category: Workflow
tags: [trocado, workflow, spec-first, litestar, http]
---

Wire a use case to the **Litestar** web edge end to end, enforcing the project's non-negotiable rules.

**Input**: a short description of the endpoint (e.g., `/trocado:endpoint expose create-budget as POST /v1/budgets`).
If omitted, ask which use case/operation to expose.

**Steps**

1. **Spec first — this gate is non-negotiable.**
   Exposing a use case over HTTP is an **API contract** (feature behavior). Check whether an OpenSpec change
   already covers it:
   ```bash
   openspec list --json
   ```
   - Relevant change exists → announce `Using change: <name>` and go to step 2.
   - None → **do not write any edge code.** Invoke `openspec-propose` (explore first with `openspec-explore` if
     fuzzy) to create the change — define the route(s), success status, the response read-model, and which
     domain errors map to which HTTP status. Get it reviewed/approved before continuing.

2. **Scaffold the Litestar edge.**
   Invoke the `web-endpoint` skill. It reads the change's specs/tasks and generates only what the change needs:
   the native class controller (body bound to the reserved `data`, `@post()` → 201, no lib name), Pydantic v2
   request/response DTOs with OpenAPI docs, dedicated request/response mappers, the feature `Router` with
   **scoped** native DI mounted under `/v1`, and the feature's pure error→status table with **router-scoped**
   handlers answering in the unified pt-BR envelope. The framework stays in `infrastructure/http/` + the
   composition root; `domain/`/`application/` are untouched.

3. **Scaffold the tests.**
   Invoke `feature-tests`: an HTTP integration test through Litestar's `TestClient` against `build()` (success
   status, the unified error envelope, the in-memory store persisting across requests in one run), plus
   plain-Python unit tests for the pure pieces (error→status table, `error_code`, the pt-BR message lookups),
   mirroring the source under `tests/<ctx>/infrastructure/http/...`.

4. **Implement against the tasks.**
   Work the change's tasks (`openspec-apply-change`). Keep code and spec in sync — behavior changes update the
   spec in the **same** change, never silently.

5. **Quality gate.**
   `uv run poe check` (format-check → lint → mypy strict → pytest) green. Smoke it if useful: `uv run poe serve`
   then exercise `request.http` or Swagger at `http://127.0.0.1:8000/schema/swagger`.

6. **Guard before done.**
   Invoke `architecture-guard` on the diff — it checks the web edge too (Litestar confinement, `data`-bound body,
   layered/router-scoped DI & error handlers, `/v1` prefix, unified envelope, `errors/` layout). Resolve every
   🔴 blocker; report the verdict.

7. **Archive when complete.** Suggest `openspec-archive-change`.

See `CLAUDE.md` → "The web edge (Litestar)" and "HTTP errors — one unified envelope".
