---
name: "Trocado: Guard"
description: Audit the current changes against Trocado/Cordato's non-negotiable rules (spec-first, async, layering, naming, derive-don't-store, money, soft-delete, authorization, one-concept-per-file, value-object-earns-existence, gateways/ bucket, determinism ports, pt-BR non-leaking error messages, test layout).
category: Quality
tags: [trocado, review, architecture, conventions]
---

Run the architecture audit on the current work.

**Input**: optionally a path, feature, or change to scope to (e.g., `/trocado:guard features/expenses`). If omitted, audit the current uncommitted diff.

**Steps**

1. Invoke the `architecture-guard` skill with the given scope (or the current diff if none given). It now also
   checks one-concept-per-file, value-object-earns-existence, the `gateways/` bucket (no folder-per-tool),
   determinism ports (no `uuid`/`datetime` in the domain), pt-BR non-leaking error messages, and test layout.
2. Report findings grouped by severity (🔴 Blocker · 🟡 Convention · 🟢 Note), each with `path:line`, the
   rule broken, and the fix.
3. End with the verdict: **PASS** or **CHANGES REQUIRED** (with blocker count).
4. Only apply fixes if the user explicitly asks — by default this command reports, it does not mutate.

> For the build gate (format / lint / types / tests) run `uv run poe check` — that is complementary to this
> architectural audit, not part of it.

See `CLAUDE.md` for the rules being enforced.
