---
name: "Trocado: Feature"
description: Start a feature the spec-first way — ensure an OpenSpec change exists, scaffold the module per conventions, then guard it.
category: Workflow
tags: [trocado, workflow, spec-first, scaffold]
---

Drive a new Trocado/Cordato feature end to end, enforcing the project's non-negotiable rules.

**Input**: a short description of the feature (e.g., `/trocado:feature record an expense`). If omitted, ask what the feature is.

**Steps**

1. **Spec first — this gate is non-negotiable.**
   Check whether an OpenSpec change already covers this work:
   ```bash
   openspec list --json
   ```
   - If a relevant change exists → announce `Using change: <name>` and go to step 2.
   - If none exists → **do not write any feature code.** Invoke the `openspec-propose` skill to create the
     change (use `openspec-explore` first if the requirement is still fuzzy). Get it reviewed/approved
     before continuing. The spec describes *what* and *why* before *how*.

2. **Scaffold per conventions.**
   Invoke the `feature-scaffold` skill. It reads the change's specs/tasks and generates only the files the
   change needs — correct layering (`domain` / `application` / `infrastructure`), canonical naming, async
   ABC ports, dedicated mappers, the `gateways/` bucket, determinism ports (clock/id via uuid7), one-concept-
   per-file, exact-decimal money, derive-don't-store (no `Expense → Budget` link). No `Model`/`ModelMapper`
   until the ORM lands — scaffold a runnable in-memory vertical slice.

3. **Scaffold the tests.**
   Invoke the `feature-tests` skill: one test file per unit mirroring the source, fakes in their own files
   under `tests/<ctx>/fakes/`, integration tests at the module root under `tests/<ctx>/integrations/`.

4. **Implement against the tasks.**
   Work through the change's tasks (the `openspec-apply-change` skill). Keep code and spec in sync — if
   behavior must change, update the spec in the **same** change, never silently.

5. **Quality gate.**
   Run `uv run poe check` (format-check → lint → mypy strict → pytest). Everything green before guarding.

6. **Guard before done.**
   Invoke the `architecture-guard` skill on the diff. Resolve every 🔴 blocker. Report the final verdict.

7. **Archive when complete.**
   Once implemented and guarded, suggest `openspec-archive-change`.

See `CLAUDE.md` → "Non-negotiable process rule: spec first, always" and "Architecture & conventions".
