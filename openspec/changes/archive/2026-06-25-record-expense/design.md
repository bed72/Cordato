## Context

This is the second domain feature, built on the conventions proven by `register-person` and the
`core-determinism` kernel (the async `ClockInterface` / `IdentifierProviderInterface` ports and their
adapters already live under `core/`). The architecture is fixed by `CLAUDE.md`: Clean Architecture + DDD
+ Ports & Adapters, a modular monolith, async at every I/O boundary, a pure synchronous `domain/`, strict
naming, a dedicated mapper at every hop, exact-decimal money, soft-delete, and per-person authorization.

The expense is the cheapest entity in the graph to model correctly because it deliberately points to
nothing: the central modeling principle is **derive, don't store**, and the expense→budget association is
the canonical example of an association that must *not* exist. The web framework and ORM remain deferred
project-wide, so this ships as a runnable, fully testable slice: pure `domain/` + an application port + an
in-memory adapter, with no `Model`/`ModelMapper` until the ORM is chosen.

## Goals / Non-Goals

**Goals:**
- A pure `ExpenseEntity` plus the rules expressing a valid expense (positive money, pure date, optional
  normalized description), with **zero** budget reference.
- `MoneyValueObject` in the shared kernel — exact-decimal, BRL, centavo-precise — reusable by budgeting
  later.
- An async `CreateExpenseUseCase` orchestrating: build money → build entity (id + now from ports) →
  persist → return public data.
- An async `ExpenseRepositoryInterface` with a working in-memory adapter.
- Deterministic, fast unit tests for every spec scenario, reusing the existing core fakes.

**Non-Goals:**
- No listing/querying of expenses and **no `find_in_range`** (the budget-belonging derivation) — that
  arrives with the change that introduces budgets or expense listing.
- No editing or soft-deleting of an expense (the entity carries `deleted_at`, but no use case mutates it
  yet).
- No verification that `person_id` refers to an existing/active person — no cross-context call into
  `identity`. Ownership/authorization is enforced upstream when auth lands.
- No web/HTTP layer, no ORM/SQL persistence, no `ExpenseModel`/`ExpenseModelMapper`.
- No currency dimension — everything is BRL; a `Currency` type is speculative and omitted.

## Decisions

**Decision 1 — New `expenses` context, mirroring the `identity` layout.** Create
`src/trocado/features/expenses/` with `domain/`, `application/`, `infrastructure/` and the same internal
folders. No deviation from the canonical structure; this is the second instance of the pattern, not a new
one.

**Decision 2 — `MoneyValueObject` lives in the shared kernel (`core/domain/`), not in `expenses`.**
Money is needed by `expenses` first, but it is intrinsically shared: budget `amount`, `total_spent`,
`remaining`, and the couple aggregates are all money. Placing it in `expenses` would force budgeting to
import across sibling features (a horizontal dependency the architecture forbids — there is no `shared/`,
`core/` is the one shared home). So `MoneyValueObject` → `core/domain/value_objects/money_value_object.py`
and its `InvalidMoneyError` → `core/domain/errors/invalid_money_error.py`. This creates `core/domain/` for
the first time, completing the kernel's three-layer shape (`domain/` · `application/` · `infrastructure/`),
exactly as `CLAUDE.md` describes for `core/`.
*Alternative considered:* define Money inside `expenses` and move it to `core` when budgeting needs it.
Rejected — we already know it is shared; deferring the move only guarantees a later churn and a window
where the dependency points the wrong way.

**Decision 3 — What `MoneyValueObject` enforces, and what it deliberately does not.** It is a `frozen`
value object wrapping a single `Decimal value`. On construction it:
- rejects non-finite values (NaN / Infinity) → `InvalidMoneyError`;
- rejects more than two decimal places → `InvalidMoneyError` (we **reject**, never silently round —
  losing centavos is a correctness bug, not a formatting one);
- normalizes the scale to exactly two places (e.g. `Decimal("19.9")` is stored as `19.90`) so equality is
  reliable.

It does **not** constrain the sign. Money is allowed to be zero or negative because the same type must
later represent `remaining`, which goes negative when a budget is overspent. *"Amount must be positive"*
is therefore **not** a money rule — it is an *expense* rule (Decision 5). This keeps Money a faithful,
reusable money type rather than baking one feature's policy into the kernel.
Money **earns its existence** strongly: exact-decimal enforcement, centavo normalization, and (later)
arithmetic are real invariants and behavior — never primitive-wrapping. Arithmetic (`add`/`subtract` for
sums) is **not** added now: nothing sums money in this change. It arrives, on this same class, with the
first read model that aggregates (`total_spent`). Adding it now would be speculative.
*Input type:* the constructor takes a `Decimal` (the application command carries a `Decimal`); it never
accepts `float`, so no binary-float value can enter the domain.

**Decision 4 — `ExpenseEntity`: a fact that points to nothing.** Fields: `id: str`,
`created_at: datetime`, `person_id: str`, `amount: MoneyValueObject`, `date: date`,
`description: str | None`, `deleted_at: datetime | None`. It is a `@dataclass(eq=False, slots=True)` with
identity equality on `id` (`__eq__`/`__hash__`), exactly like `PersonEntity`. The only sanctioned
constructor is a pure `create(...)` factory that sets `deleted_at = None` and enforces the positivity rule
(Decision 5). **There is no `budget_id` and there never will be** — this absence is the feature, per the
"association that deliberately does NOT exist" in `CLAUDE.md`.
- `person_id` is a plain opaque `str` (the owner's id), not a value object and not a foreign-key object —
  the domain never inspects it, mirroring how `PersonEntity.id` is treated.
- `date` is the stdlib `datetime.date` (no time), the sole basis for future date-range belonging.

**Decision 5 — Positivity is an expense rule, enforced in the factory, raising `InvalidAmountError`.**
`ExpenseEntity.create(...)` rejects an amount `<= 0` with `InvalidAmountError`
(`domain/errors/invalid_amount_error.py`, message *"Valor deve ser maior que zero."* — non-sensitive, so
stating the rule is fine and leaks nothing). Putting the check in the factory (not the use case) keeps the
invariant with the entity: no caller can build a zero/negative expense.
*Alternative considered:* enforce positivity inside `MoneyValueObject`. Rejected per Decision 3 — Money
must allow non-positive values for `remaining`.

**Decision 6 — Description is a plain `str | None`, normalized in the factory; no value object.** A
description carries no invariant beyond "trim, and blank means absent" — that is trivial normalization,
not a domain rule worth a class. Per *value-object-earns-its-existence*, it stays a primitive. The factory
trims and maps empty/whitespace-only to `None`.
*Alternative considered:* a `DescriptionValueObject`. Rejected as primitive-wrapping / over-engineering.

**Decision 7 — Identity and timestamp via the existing core ports (no new ports).** The use case depends
on `core`'s `IdentifierProviderInterface` (`uuid7` adapter) and `ClockInterface`, obtains `id` + `now`,
and passes them into `ExpenseEntity.create(...)`. The pure domain calls neither `uuid` nor `datetime`.
This reuses the kernel verbatim — the payoff the determinism ports were built for.

**Decision 8 — `ExpenseRepositoryInterface` is minimal: just `create`.** One async method,
`async def create(expense: ExpenseEntity) -> None`, an `abc.ABC` with an `@abstractmethod`, taking/returning
domain entities. Recording needs nothing more. `find_in_range(person, start, end)` — the method that will
*derive* expense→budget belonging with no FK — is **not** added here; it belongs to the change that first
reads expenses (budgets / listing), where it can be specified and tested against real query scenarios.
Soft-deleted rows being excluded from normal reads is the repository's responsibility, recorded here for
when a read method lands.
*Alternative considered:* add `find_in_range` now for completeness. Rejected — YAGNI and, more
importantly, an unused read method would be specified without the scenarios that give it meaning.

**Decision 9 — In-memory adapter, no Model/Mapper.** `ExpenseRepository`
(`infrastructure/repositories/expense_repository.py`) stores entities in a `dict` keyed by `id`, exactly
like `PersonRepository`. "In-memory" is an implementation detail, absent from the class name (the tool
hides inside the file). **No `ExpenseModel` / `ExpenseModelMapper`** — they bridge a table that does not
exist yet; inventing an in-memory "model" would be ceremony. They arrive with the ORM change, behind this
same port.

**Decision 10 — Application shapes and the one mapper this slice needs.** `CreateExpenseData` (command:
`person_id: str`, `amount: Decimal`, `date: date`, `description: str | None`) is the use-case input;
`ExpenseData` (read-model: `id`, `person_id`, `amount: Decimal`, `date`, `description`, `created_at`) is
the output. A dedicated `ExpenseDataMapper` converts `ExpenseEntity → ExpenseData` (unwrapping
`MoneyValueObject` to its `Decimal`), as a `@staticmethod`. No web Request/Response mapper exists yet (no
web layer). The command carries a raw `Decimal`, not a `MoneyValueObject`: the application speaks
primitives at its edge and the use case builds the domain VO (so an invalid amount is rejected as a domain
error, in one place).
*Naming:* the use case and command use the `Create…` verb (`CreateExpenseUseCase`, `CreateExpenseData`)
while the capability stays `record-expense` — mirroring the established `register-person` precedent exactly
(`CreatePersonUseCase` / `CreatePersonData` under the `register-person` capability). The behavioral verb
("record") names the capability; the application uses the uniform `Create…` shape for the create-an-entity
use case.

## Risks / Trade-offs

- **In-memory persistence is not durable** → Acceptable: this slice locks the domain + use-case contract
  and is testable now; durability arrives with the ORM change, behind the unchanged port.
- **`person_id` is not validated against `identity`** → Deliberate: validating it would couple `expenses`
  to `identity` and pre-empt the auth design. The owner reference is trusted here and enforced upstream
  when authentication/authorization lands. Documented so it is a decision, not an oversight.
- **Money has no arithmetic yet** → Intentional (Decision 3); it is added on the same class when the first
  aggregation use case needs it, avoiding speculative API.
- **Rejecting (not rounding) >2-decimal amounts may surprise a caller** → Correct trade-off: silently
  rounding money is a worse surprise. The web layer can format/round input before it reaches the command.
- **`deleted_at` exists with no use case to set it** → Accepted: it is part of the entity's true shape
  (soft-delete is the domain's lifecycle); wiring a delete use case is a separate change.

## Migration Plan

Additive only — a new feature module and the first occupant of `core/domain/`. No new dependency, no
persistence schema, nothing to roll back beyond removing the new files.

## Open Questions

- **Future-dated expenses:** should the domain reject a `date` after "today"? Leaning no for now (an
  expense is a recorded fact; the clock-vs-date comparison and its timezone implications are better left
  until there is a reason). Revisit if a rule emerges.
- **Money rounding policy at the edge:** when the web layer arrives, decide whether it rounds/validates
  user input to two places before building the command, or surfaces `InvalidMoneyError` to the user. Out
  of scope here.
