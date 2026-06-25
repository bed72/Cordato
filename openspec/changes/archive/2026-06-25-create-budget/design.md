## Context

`expenses` shipped as an in-memory vertical slice: pure `domain/`, async ABC ports in `application/`, an
in-memory repository adapter, reusing the shared-kernel `MoneyValueObject`, `ClockInterface`, and
`IdentifierProviderInterface`. `budgeting` is the next slice and must mirror that shape exactly. It introduces
the first two of the model's load-bearing invariants — per-person **non-overlap** and **derive-don't-store**
belonging — so the design's job is to place each rule in the correct layer and keep the expense→budget link
out of storage. Web and ORM remain deferred; no `Model`/`ModelMapper` yet.

## Goals / Non-Goals

**Goals:**
- A `budgeting` feature with `BudgetEntity`, `CreateBudgetUseCase`, an active-budget read, an async budget
  repository port + in-memory adapter, and dedicated data/mappers — all per the project conventions.
- Enforce `start_date <= end_date` and non-positive-amount rejection in the **pure domain** (the entity
  factory), with no I/O.
- Enforce the per-person non-overlap invariant in the **use case**, because it needs the repository to read
  the person's existing live budgets — an I/O fact the pure entity cannot know alone.
- Derive the active budget and its `total_spent`/`remaining` at read-time, summing expenses by date range with
  **no foreign key**.

**Non-Goals:**
- The "No budget" default bucket, the couple/combined view, and notifications — out of scope, later changes.
- ORM/web/`Model`/`ModelMapper` — still deferred behind the ports.
- Editing or soft-deleting budgets — this change only creates and reads.
- Caching derived numbers — current project decision is no cache.

## Decisions

**Where each rule lives.**
- `start_date <= end_date` and amount > 0 are **intrinsic to a single budget** → enforced in
  `BudgetEntity.create(...)`, the only sanctioned constructor, raising `InvalidBudgetRangeError` /
  reusing the money/amount rejection. Pure, deterministic, no I/O.
- **Non-overlap** is a fact *across* a person's budgets → it cannot be known by one entity in isolation, so it
  lives in `CreateBudgetUseCase`, which asks the repository for the person's live budgets and checks the new
  range against them before persisting, raising `OverlappingBudgetError`. Alternative considered: push the list
  into the entity factory — rejected, because it would force the pure domain to receive a pre-fetched
  collection and blur the "domain does no I/O" line; the use case is the right home for an invariant that
  depends on stored state.

**Overlap test.** Two inclusive ranges `[a_start, a_end]` and `[b_start, b_end]` overlap iff
`a_start <= b_end AND b_start <= a_end`. Boundary days count as overlap (shared day rejected), matching the
spec's "not even the boundary day". A small pure helper on the entity (e.g. `overlaps(other) -> bool`) keeps
the comparison in the domain and unit-testable without the use case.

**Active budget as a Virtual Object, derived.** The enriched active budget is modeled as a **Virtual Object** —
a third domain shape, neither entity nor value object (see CLAUDE.md "Virtual objects … Where they live").
`ActiveBudgetVirtualObject` holds the `BudgetEntity` plus the summed `total_spent: MoneyValueObject` and exposes
`remaining` as a derived property (`amount − total_spent`), keeping the money math in the domain. The
active-budget use case: (1) asks the budget repository for the person's live budget containing the day; (2) if
found, reads the total spend over the budget's range through budgeting's **own** `SpendReaderInterface`
(never the expenses port); (3) builds the `ActiveBudgetVirtualObject` and maps it through
`ActiveBudgetDataMapper.to_data(active)` to its own `ActiveBudgetData` read-model — one cohesive argument,
never a multi-parameter mapper.

Decision: this **replaces** an earlier draft where a single `BudgetData` carried optional/nullable
`total_spent`/`remaining`. Rejected because it conflated two read-models (the plain create response vs. the
enriched read) into one nullable shape and forced the mapper to take `(budget, total_spent)` as loose
parameters — a signature that grows as derived fields multiply. Splitting the two read-models and giving the
enrichment a domain Virtual Object keeps every mapper at exactly one input and removes the nullability. The
plain create response stays as `BudgetData` (no spend fields), mapped by `BudgetDataMapper.to_data(budget)`.

**Module independence — budgeting owns the abstraction it consumes (DIP).** Summing spend needs expense
data, which another context owns. A feature module MUST depend only on `core`, never on a sibling — so
budgeting does **not** import `ExpenseRepositoryInterface`. Instead it declares its **own** gateway port,
`SpendReaderInterface.total_spent(person_id, start, end) -> MoneyValueObject`, stated in budgeting's own
language (a total, not "expenses") and returning a core value object. The use case depends on that.

- **Gateway, not repository.** `SpendReader` reads data budgeting does not own and returns a core value with
  no entity↔table mapping → it belongs in `gateways/`, not `repositories/`. The repository bucket stays
  reserved for budgeting's own aggregate (`BudgetRepository`).
- **Where the implementing adapter lives.** Outside budgeting's domain/application. Today (in-memory slice) a
  composition-root bridge in the integration test sums the real expenses ledger via the expenses
  `find_in_range` read method; unit tests use a `FakeSpendReader`. When the ORM lands, a
  `budgeting/infrastructure/gateways/` adapter queries the shared expenses table directly — duplicating only
  the tiny read query, with zero code dependency on `expenses`. The production gateway is **deferred** like
  `Model`/`ModelMapper`, for the same reason (it needs the shared DB).
- **Why not core / why not a hard dependency.** `Expense` is a feature aggregate, not shared kernel — moving
  it to `core` would bloat the kernel and couple every module to it. Depending on the expenses port (the
  earlier draft) was rejected: it makes budgeting un-deployable without expenses, breaking the independence
  premise. The `find_in_range` read method stays on the expenses side, used only by the composition-root bridge.

**One concept per file; mappers static; ports async ABC.** Every entity, error, port, use case, data, and
mapper in its own file. `BudgetDataMapper.to_data(...)` is a `@staticmethod`. Repository ports are
`abc.ABC` + `@abstractmethod`, async by contract; the adapter is `BudgetRepository` (no lib name).

## Risks / Trade-offs

- [Non-overlap checked in the use case is a read-then-write with no transaction] → Acceptable now: the slice is
  in-memory and single-threaded; when the ORM lands, the invariant gets a DB-level guard (exclusion constraint
  or a transactional check) behind the same port. Documented so it is not mistaken for a domain-purity slip.
- [Deriving spend on every active-budget read re-sums expenses] → Acceptable per the project's explicit "NO
  cache" decision — a couple is little data and the sum is instant. Revisit only if profiling ever says so.
- [Adding `find_in_range` to the expenses port touches another feature] → Additive only (new abstract method +
  in-memory impl); no existing record-expense behavior changes, so no record-expense spec delta is needed.
- [Boundary-day semantics are easy to get wrong] → Pinned by explicit scenarios (adjacent allowed, shared
  boundary rejected) and a dedicated pure `overlaps` unit test.

## Open Questions

- Should the expenses port expose `find_in_range` (returns entities) or `sum_in_range` (returns `Decimal`)?
  Leaning `find_in_range` for reuse by the future couple view; final call at implementation, but the spec is
  agnostic to which.
- Does "no active budget for the day" surface as `None` from the use case or a dedicated absence type? Leaning
  `None` for now (the "No budget" default bucket is a separate later capability).
