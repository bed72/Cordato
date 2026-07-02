---
name: feature-layers
description: Place and name Kotlin code across Cordato's hexagonal layers (domain/application/infrastructure) with the right category suffix. Use when creating or editing a bounded context, use case, port, adapter, repository, entity, value object, enum, or domain error.
metadata:
  author: cordato
  version: "1.0"
---

Reinforces the structural conventions in `CLAUDE.md`. This skill is about *where code goes and what it's named* — it does not authorize new behavior. Behavior still needs an approved OpenSpec change first (see `/opsx:propose` and `/opsx:apply`).

## Before writing anything

1. Read the relevant `README.md` (repo root + `features/<context>/README.md`) — that's the source of truth for business rules.
2. Open the **reference slice** and mirror it: `features/identity/` (SignUp). It shows every rule below applied in real code. Don't invent a shape; copy this one.

## Layer placement (dependencies point inward: infrastructure → application → domain)

| Put it in… | When it is… | Category suffix |
|---|---|---|
| `domain/entities/` | an identity-bearing thing | `…Entity` |
| `domain/value_objects/` | an immutable value (`@JvmInline value class`, private ctor + `of()` returning null on invalid) | `…ValueObject` |
| `domain/virtual_objects/` | a read-time projection composed from entities, never persisted (plain `data class`) | `…VirtualObject` (or descriptive) |
| `domain/enums/` | a closed set | `…Enum` |
| `domain/errors/` | a failure case | `sealed`, `…Error` |
| `application/commands/` | use-case input | `…Command` |
| `application/results/` | use-case output read-model | `sealed`, `…Result` |
| `application/use_cases/` | orchestration | `…UseCase`, driving side = public `operator fun invoke` (no extra interface) |
| `application/ports/` | a driven contract the app needs from outside | `…Port` |
| `application/repositories/` | a persistence contract | keeps DDD suffix `…Repository` |
| `infrastructure/adapters/` | a port implementation touching a library | `…Adapter` |
| `infrastructure/repositories/` | a repository implementation | `InMemory…Repository` / `…Repository` |
| `infrastructure/di/` | Koin wiring (composition root only) | `…Module` |

Cross-cutting code (money, clock, id generation, token/session) → `core/`, same three layers. There is deliberately **no** `shared/`.

## Hard rules (the arch test enforces these at build time)

- `domain/` imports nothing from `application/`, `infrastructure/`, Koin, or any library.
- `application/` never imports `infrastructure/` or a DI annotation.
- Only `couple` may reference sibling contexts (`budget`, `expense`) — and only via a port it defines in `couple/application/ports/`, implemented in `couple/infrastructure/adapters/`. `budget`/`expense`/`identity` never import a sibling.
- **Derive, don't store**: no foreign key for query convenience (e.g. `Expense` never references `Budget`; budget membership is computed by date range at read time).

## Finish

- Money is integer cents / fixed-scale `BigDecimal`, never `Double`; BRL only.
- Errors are returned as sealed types, never thrown.
- Run `./gradlew test` — `ArchitectureTest` (Konsist) will fail the build on a layering violation.
- Add tests per the **writing-tests** skill.
