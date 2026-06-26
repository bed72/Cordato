## Context

`Budget` was modeled from day one with a `deleted_at` field, but nothing has ever set it: there is no removal
path for an ordinary budget today. The only budget removal that exists is the account hard-delete's physical
cascade (`erase_for_person`). `delete-expense` just established the first **day-to-day soft-delete** on an
individual entity; this change does the symmetric thing for `Budget`, realizing "reversible without loss" at
the level it was always meant for and closing an obvious asymmetry (an expense can be retired, a budget
cannot).

The slice is small and rides entirely on patterns already in the codebase: `ExpenseEntity.delete(at)` +
`DeleteExpenseUseCase` (authorization-is-the-lookup, clock-stamped soft-delete) are a near-exact template, and
the `BudgetRepositoryInterface` already distinguishes live reads (`list_live_for_person`,
`find_active_for_person` return only live rows) from the physical cascade (`erase_for_person`). Current build
stage is still pre-web/pre-ORM, so this ships as a runnable in-memory vertical slice behind the existing ports.

## Goals / Non-Goals

**Goals:**
- One domain transition `BudgetEntity.delete(at)` that stamps `deleted_at`, mirroring `ExpenseEntity.delete`.
- A `DeleteBudgetUseCase` whose authorization is a requester-scoped lookup and whose error never leaks.
- Establish the audit half of soft-delete on budgets: normal reads already exclude removed rows; add an
  explicit `list_including_removed` audit read that sees everything.
- Demonstrate "derive, don't store" a second time: the deletion reads/writes no expense and no other budget,
  yet the freed date range reopens for `create-budget` and the covered expenses fall to the default bucket.

**Non-Goals:**
- Restoring/undeleting a budget (clearing `deleted_at`) — a separate change if ever wanted.
- Editing a budget (amount/dates/note) or listing budgets for a UI — sibling slices, each its own change.
- HTTP handler, ORM model/mapper, notifications — deferred with the web layer behind the unchanged ports.

## Decisions

**Authorization = a requester-scoped lookup, not a fetch-then-check.**
The port gains `find_active_by_id(person_id, budget_id) -> BudgetEntity | None`, scoped to *owner + id +
live*. The use case treats `None` as `BudgetNotFoundError`. This folds three failure modes (unknown id,
foreign owner, already-deleted) into one indistinguishable rejection, which is exactly what non-leaking
authorization requires.
- *Alternative considered:* `find_by_id(budget_id)` then compare `budget.person_id` in the use case. Rejected:
  it pulls another person's row into the application layer and tempts a leaky branch ("exists but not yours");
  scoping the query keeps the secret in the repository, mirroring `delete-expense`'s `find_active_by_id`.

**Soft-delete is a domain transition, stamped from the clock port — never `datetime.now()` in the domain.**
`BudgetEntity.delete(at: datetime)` sets `self.deleted_at = at`. The use case obtains `at` from the
`ClockInterface` and passes it in, keeping the domain pure and deterministic under test (identical to how
`DeleteExpenseUseCase` stamps the removal).
- *Alternative considered:* a richer `delete()` that guards against double-deletion in the entity. Rejected:
  the scoped lookup already guarantees only live budgets reach `delete`, so an in-entity guard would be dead
  code; `delete` stays a single unconditional stamp, like `ExpenseEntity.delete`.

**Add `list_including_removed` now, with this soft-delete.**
CLAUDE.md defines soft-delete as "mistake recovery + **audit trail**", with `list_including_removed` as the
one method that sees everything. Introducing the audit read alongside the soft-delete is what makes the slice
meaningfully testable (assert the row is gone from `find_active_for_person`/`list_live_for_person` yet present
in the audit read) and completes the repository's two-read contract — symmetric to the one
`delete-expense` established on `ExpenseRepositoryInterface`.
- *Alternative considered:* defer the audit read to a later "list budgets" change. Rejected: without it, the
  spec's "survives for audit" half is unobservable and the soft-delete looks indistinguishable from a delete.

**No new behavior in `create-budget`, `active-budget`, or `default-budget` — the derivations already reason
over live budgets.**
`list_live_for_person` (the non-overlap check's input) and `find_active_for_person` already exclude
`deleted_at != null`. So "the freed range reopens" and "the covered expenses fall to the default bucket" are
not new rules — they are existing behavior observed once a budget can finally be removed. This change adds
repository methods and a use case; it modifies no prior capability's requirements.

**No `asyncio.gather`.** The flow is a strict data dependency chain: resolve → (guard) → `clock.now()` →
`entity.delete` → `repository.delete`. There are no two independent awaits to overlap, so the calls stay
sequential, per the async rule.

## Risks / Trade-offs

- **[The in-memory `find_active_by_id` and `list_including_removed` could drift from the eventual ORM adapter's
  soft-delete semantics.]** → The port contract is explicit (normal reads exclude `deleted_at != null`; the
  audit read includes it); the ORM adapter will be held to the same scenarios when it lands, behind the same
  port, without touching `domain/`/`application/`.
- **[`list_including_removed` is added before a feature consumes it as a read-model, risking a speculative
  method.]** → It is not speculative: it is the observable half of *this* change's audit guarantee and is
  exercised by this slice's tests; it is the natural primitive a later "list budgets" change will build on.
- **[Naming collision risk: `find_active_by_id` resolves a *live* budget, but budgeting also has
  `find_active_for_person`, which means "the budget covering today".]** → They are distinct, intentional verbs
  on the same port: `find_active_for_person(person_id, day)` is the date-containment derivation; `..._by_id`
  is the live-row authorization lookup. The shared word "active" reads as "not soft-deleted" in both, which is
  consistent; the docstrings spell out the difference, mirroring `delete-expense`'s `find_active_by_id`.

## Migration Plan

Additive only — no existing behavior changes. New domain method, new error, three new port methods (one
mutating, one scoped read, one audit read), one new use case + command. The in-memory `BudgetRepository`
implements the new methods; existing `create`/`list_live_for_person`/`find_active_for_person`/
`erase_for_person` are untouched. No data migration (pre-ORM). Rollback is removal of the additive surface.

## Open Questions

- **Restore/undo** is deliberately out of scope. If product later wants it, it is its own capability that
  clears `deleted_at` under the same scoped-lookup authorization — noted here so the omission is intentional,
  not forgotten. (One wrinkle a restore change must handle that delete does not: restoring a budget must
  re-check the non-overlap invariant against the now-live set, since the freed range may have been re-occupied
  in the meantime.)
