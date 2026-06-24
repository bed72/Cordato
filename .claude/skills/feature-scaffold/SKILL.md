---
name: feature-scaffold
description: Scaffold or extend a Trocado/Cordato feature module (domain / application / infrastructure) following the project's layer structure, naming conventions, async ABC ports, dedicated mappers, the gateways/ bucket, determinism ports (clock/id), and one-concept-per-file. Refuses to scaffold unless an OpenSpec change covering the work already exists — enforcing spec-first. Use when starting a new context/feature or adding an entity, value object, use case, repository, gateway, mapper, or model to one.
metadata:
  author: trocado
  version: "2.0"
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

Each module is three layers. **One concept per file** everywhere — one value object, enum, error, port, use
case, mapper, or gateway per file. Never bundle.

```
features/<context>/
  domain/
    entities/            # <name>_entity.py        → <Name>Entity         (pure Python, sync)
    value_objects/       # <name>_value_object.py  → <Name>ValueObject ; enums also here (person_status.py → PersonStatus)
    errors/              # <name>_..._error.py      → <Name>...Error      (one class per file)
    policies/            # optional — pure rules
    services/            # optional — pure domain services (no I/O)
  application/
    interfaces/          # <name>_repository_interface.py → <Name>RepositoryInterface  (abc.ABC, async)
                         # also the determinism ports: clock_interface.py, identifier_provider_interface.py
    data/                # <verb>_<name>_data.py / <name>_data.py → command / read-model
    use_cases/           # <verb>_<name>_use_case.py → <Verb><Name>UseCase  (async)
    mappers/             # <name>_data_mapper.py    → <Name>DataMapper      (entity→data)
    services/            # optional — application services
  infrastructure/
    models/              # <name>_model.py          → <Name>Model       (ONLY when the ORM lands — see stage note)
    mappers/             # <name>_model_mapper.py   → <Name>ModelMapper  (ONLY when the ORM lands)
    repositories/        # <name>_repository.py     → <Name>Repository   (persistence adapter; in-memory for now)
    gateways/            # <name>.py                → <Name>             (EVERY other outbound adapter)
```

**`infrastructure/` has exactly two buckets, by responsibility — never a folder per tool:**
- `repositories/` (+ `models/`, `mappers/`) = persistence (entity ↔ table).
- `gateways/` = every other port implementation: password hasher, clock, identifier provider, and later email/
  SMS/push senders, token generators, event publishers, payment gateways. A new outbound capability is a new
  **file** in `gateways/`, not a new folder (`hashers/`, `providers/`… are wrong).

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
10. **One concept per file.** One value object / enum / error / port / use case / mapper / gateway per file —
    never bundle related types into a shared module.
11. **A value object must earn its existence.** Generate a value object only when it enforces an invariant or
    carries behavior (validation, normalization, a domain operation). A bare wrapper around a primitive with
    no rule (a password hash, an opaque token) is over-engineering — use the primitive (`str`).
12. **Determinism via ports — never `uuid`/`datetime` inside the domain.** When an entity needs `id` /
    `created_at`, generate the `IdentifierProviderInterface` (adapter uses `uuid.uuid7()`, stdlib 3.14) and
    `ClockInterface` ports; the use case fetches both and passes them to the entity's **factory**
    (`<Name>Entity.create(...)`), which is the only sanctioned constructor and fixes the initial state.
    Entities are equal by **identity** (`id`) — generate `__eq__`/`__hash__` on `id`.
13. **Domain error messages: short pt-BR, no sensitive data.** Never echo the offending value (no account
    enumeration) — `"E-mail já está em uso."`, never the address. One error class per file.
14. **Current build stage (transitional).** No web framework / ORM yet, so scaffold a runnable vertical slice:
    `domain/` + `application/` ports + an **in-memory** `repositories/` adapter + real `gateways/`. **Do NOT
    generate `Model`/`ModelMapper`** until the ORM change lands.

## Flow

1. Run the spec-first precondition. Stop if it fails.
2. Read the change's spec/tasks to know which entities, use cases, and ports it asks for.
3. Confirm the target context with the user (existing vs new), then create only the files the change needs —
   don't over-scaffold empty layers.
4. Scaffold the **tests** alongside the code — invoke the **`feature-tests`** skill (one file per unit
   mirroring the source, fakes in their own files, integration tests at the module root).
5. Run the quality gate: `uv run poe check` (format-check → lint → mypy strict → pytest).
6. Run the **`architecture-guard`** skill on the new files and report the verdict.
