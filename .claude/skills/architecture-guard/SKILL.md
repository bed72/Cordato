---
name: architecture-guard
description: Audit Trocado/Cordato code or a diff against the project's non-negotiable rules — spec-first (every feature has an OpenSpec change), async everywhere at I/O boundaries, Clean Architecture layering and dependency direction, naming conventions, ABC ports, no library names in files/classes, a dedicated mapper at every boundary, derive-don't-store, soft-delete in the repository, exact-decimal money, and per-person authorization. Use before committing, when reviewing changes, or whenever the user asks to check architecture/convention compliance.
metadata:
  author: trocado
  version: "1.0"
---

# Architecture Guard

Audit changes against the **non-negotiable rules** defined in `CLAUDE.md`. This skill is the enforcement
arm of those rules: it reads the code, classifies each finding, and reports violations with the exact rule
they break and how to fix them. It **does not** silently fix — it reports; apply fixes only when asked.

## Scope

Default target is the **current uncommitted diff**. If the user names files, a feature, or a change, scope
to that instead. State what you audited.

```bash
git diff --stat 2>/dev/null || echo "(not a git repo — audit the files the user named)"
```

## The checklist

Go through every category. For each violation report: `path:line` · the rule broken · the fix.

### 1. Spec first (process)
- Does this change implement or alter **feature behavior**? If yes, there MUST be a corresponding OpenSpec
  change. Verify one exists and covers it:
  ```bash
  openspec list --json 2>/dev/null
  ```
- Behavior that diverges from the spec is a bug in **one of them** — never "ignore the spec". Flag drift.
- Pure refactor / build-infra / typo with no behavior change is exempt — but if in doubt, flag it as
  "needs a change".

### 2. Async everywhere
- Every **port** (interface ABC) method that touches I/O is `async def` returning an awaitable.
- Every **adapter** (repository/infra), **use case**, and **web handler** is `async` and `await`ed end to end.
- **No blocking call on the event loop.** A sync-only dependency must be wrapped off-loop (thread executor)
  **at the adapter edge** — never leaked inward. No hidden `.run()` / `asyncio.run()` bridge inside a method.
- The pure `domain/` (entities, value objects, policies, no-I/O services) stays **synchronous** — flag
  `async def` on a pure-compute domain method as empty ceremony.

### 3. Dependency direction & layering
- Imports point **inward only**: `infrastructure → application → domain`. Flag any `domain/` file importing
  from `application/` or `infrastructure/`, and any `application/` file importing `infrastructure/`.
- `domain/` imports **nothing framework/lib**. Pure Python only.
- A library/ORM is known **only** inside `infrastructure/`.

### 4. Naming conventions (apply to ALL modules)
Flag any mismatch with the canonical table:
| Concept | Folder | File suffix | Class suffix |
|---|---|---|---|
| Entity | `domain/entities` | `_entity.py` | `Entity` |
| Value Object | `domain/value_objects` | `_value_object.py` | `ValueObject` |
| Error | `domain/errors` | `_error.py` | `Error` |
| Interface (port) | `application/interfaces` | `_repository_interface.py` (etc.) | `Interface` |
| Implementation | `infrastructure/repositories` | `_repository.py` | `Repository` |
| Use case | `application/use_cases` | `_use_case.py` | `UseCase` |
| Data (command/output) | `application/data` | `_data.py` | `Data` |
| Mapper entity↔model | `infrastructure/mappers` | `_model_mapper.py` | `ModelMapper` |
| Mapper entity→data | `application/mappers` | `_data_mapper.py` | `DataMapper` |
| Model (table) | `infrastructure/models` | `_model.py` | `Model` |

### 5. The hard "never" rules
- **No library name in a file or class.** `ExpenseRepository`, never `SqlAlchemyExpenseRepository`. The tool
  hides *inside* the file. Flag any class/file carrying a lib name.
- **Interfaces always via `abc.ABC` + `@abstractmethod`.** No duck-typed/Protocol-only ports.
- **No abbreviations.** `value_objects` not `vos`; `MoneyValueObject` not `MoneyVO`.
- **A dedicated mapper class at every boundary** — never inline conversion across Request↔Data↔Entity↔Model.

### 6. Domain-model integrity (derive, don't store)
- **`Expense` has zero link to `Budget`.** Flag any `budget_id` on an expense (model, entity, or data) or any
  stored expense→budget association. Belonging is computed at read-time by date range.
- Budget/couple aggregates (`total_spent`, `remaining`, couple budget/expenses) are **computed**, not stored
  columns. Flag persisted aggregate fields (current decision: **no cache**).
- Don't add a stored reference where attribute-derived association would do.

### 7. Money & dates
- Money is **exact decimal** (cents, BRL) — flag any `float` for amounts.
- Budget dates are `date` (no time), inclusive both ends. Flag `datetime` where a pure `date` is meant.

### 8. Soft-delete & authorization
- Soft-delete (`deleted_at`) is the **repository's** responsibility: normal reads exclude removed rows; only
  an explicit `list_including_removed` (audit) sees all. Flag use-case-level soft-delete filtering or normal
  reads that return removed rows.
- Account deletion is the **only** physical/hard delete (cascade + email neutralization + status flip + pair
  dissolution). Flag hard-deletes anywhere else.
- Per-person authorization: a person reads/mutates only their own data; shared (couple) views are
  **read-only**. Flag a write path reaching a partner's data.

## Output format

Group findings by **severity**:
- **🔴 Blocker** — breaks a non-negotiable rule (missing spec, sync I/O, stored expense→budget link, lib name
  in class, float money, hard-delete outside account deletion).
- **🟡 Convention** — naming/structure drift, missing dedicated mapper, abbreviation.
- **🟢 Note** — stylistic or "in doubt, confirm".

End with a one-line verdict: **PASS** (no blockers) or **CHANGES REQUIRED** (≥1 blocker), and the blocker count.
