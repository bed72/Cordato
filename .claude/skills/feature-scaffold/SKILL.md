---
name: feature-scaffold
description: Scaffold or extend a Trocado/Cordato feature module (domain / application / infrastructure) following the project's layer structure, naming conventions, async ABC ports, and dedicated mappers. Refuses to scaffold unless an OpenSpec change covering the work already exists — enforcing spec-first. Use when starting a new context/feature or adding an entity, value object, use case, repository, mapper, or model to one.
metadata:
  author: trocado
  version: "1.0"
---

# Feature Scaffold

Generate the file/folder skeleton for a Trocado/Cordato feature, wired to the conventions in `CLAUDE.md`.
This skill **encodes** the rules so generated code starts correct: spec-first, async at the boundaries,
inward dependencies, canonical naming, dedicated mappers.

## STOP — spec-first precondition (non-negotiable)

Before generating **any** code, confirm an OpenSpec change covers this work:

```bash
openspec list --json
```

- If a relevant change exists → announce `Using change: <name>` and proceed.
- If none exists → **do not scaffold.** Tell the user: *"No OpenSpec change covers this — features start
  with a spec."* Offer to run the `openspec-propose` skill (or `openspec-explore` first if the requirement
  is fuzzy), then come back. This refusal is the point of the skill.

## Layout

Code lives under `src/trocado/`. Pick the package:
- `core/` — shared kernel (same three-layer shape as a feature).
- `features/<context>/` — one of `expenses`, `budgeting`, `identity`, `pairing`, `notifications`
  (or a new context the change introduces). **There is NO `shared/`.**

Each module is three layers:

```
features/<context>/
  domain/
    entities/            # <name>_entity.py        → <Name>Entity         (pure Python, sync)
    value_objects/       # <name>_value_object.py  → <Name>ValueObject
    errors/              # <name>_..._error.py      → <Name>...Error
    policies/            # optional — pure rules
    services/            # optional — pure domain services (no I/O)
  application/
    interfaces/          # <name>_repository_interface.py → <Name>RepositoryInterface  (abc.ABC, async)
    data/                # <verb>_<name>_data.py / <name>_data.py → command / read-model
    use_cases/           # <verb>_<name>_use_case.py → <Verb><Name>UseCase  (async)
    mappers/             # <name>_data_mapper.py    → <Name>DataMapper      (entity→data)
    services/            # optional — application services
  infrastructure/
    models/              # <name>_model.py          → <Name>Model          (the only place that knows the ORM)
    mappers/             # <name>_model_mapper.py   → <Name>ModelMapper     (entity↔model)
    repositories/        # <name>_repository.py     → <Name>Repository      (async adapter)
```

## Generation rules (bake these in)

1. **Async at every I/O boundary.** Port ABCs use `async def`; the repository adapter, use cases, and any
   web handler are `async`. The pure `domain/` stays synchronous (no I/O → nothing to await).
2. **Ports are `abc.ABC` + `@abstractmethod`.** Never a Protocol, never duck typing.
3. **No library name anywhere.** `ExpenseRepository`, not `SqlAlchemyExpenseRepository`. The ORM is imported
   only inside the `infrastructure/` file body.
4. **Dependency direction inward.** `domain/` imports nothing outward; `application/` imports `domain/` only;
   `infrastructure/` may import both. No reverse imports.
5. **A dedicated mapper class per boundary** — `RequestMapper` (web), `DataMapper` (entity→data, application),
   `ModelMapper` (entity↔model, infrastructure). Never inline conversion.
6. **No abbreviations** in folders, files, or classes (`value_objects`, `MoneyValueObject`).
7. **Money is exact decimal** (cents, BRL); **dates are pure `date`** (no time), inclusive both ends.
8. **No stored `Expense → Budget` link**, no persisted aggregate columns — belonging and totals are derived
   at read-time. The repository exposes `find_in_range(person, start, end)` for date-range derivation.
9. **Soft-delete in the repository**: normal reads exclude `deleted_at != null`; add an explicit
   `list_including_removed` for audit. Don't filter soft-deletes in the use case.

## Flow

1. Run the spec-first precondition. Stop if it fails.
2. Read the change's spec/tasks to know which entities, use cases, and ports it asks for.
3. Confirm the target context with the user (existing vs new), then create only the files the change needs —
   don't over-scaffold empty layers.
4. After generating, run the **`architecture-guard`** skill on the new files and report the verdict.
