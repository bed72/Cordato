## Context

`Expense` was modeled from day one with a `deleted_at` field, but nothing has ever set it: there is no
removal path for an ordinary expense today. The only removals that exist are `Pair.dissolve` (soft) and the
account hard-delete (physical cascade). This change implements the first **day-to-day soft-delete** on an
individual entity, realizing the "reversible without loss" pillar at the level it was always meant for.

The slice is small and rides entirely on patterns already in the codebase: the `PairEntity.dissolve(at)`
transition + `DissolvePairUseCase` (authorization-is-the-lookup, clock-stamped soft-delete) are a near-exact
template, and the `ExpenseRepositoryInterface` already distinguishes live reads (`find_in_range` returns only
live rows) from the physical cascade (`erase_for_person`). Current build stage is still pre-web/pre-ORM, so
this ships as a runnable in-memory vertical slice behind the existing ports.

## Goals / Non-Goals

**Goals:**
- One domain transition `ExpenseEntity.delete(at)` that stamps `deleted_at`, mirroring `PairEntity.dissolve`.
- A `DeleteExpenseUseCase` whose authorization is a requester-scoped lookup and whose error never leaks.
- Establish both halves of soft-delete on an individual entity: normal reads exclude removed rows; an explicit
  `list_including_removed` audit read sees everything.
- Demonstrate "derive, don't store": the deletion reads/writes no budget, yet the active budget's spend
  recomputes correctly.

**Non-Goals:**
- Restoring/undeleting an expense (clearing `deleted_at`) — a separate change if ever wanted.
- Editing an expense, deleting a budget, or listing expenses for a UI — sibling slices, each its own change.
- HTTP handler, ORM model/mapper, notifications — deferred with the web layer behind the unchanged ports.

## Decisions

**Authorization = a requester-scoped lookup, not a fetch-then-check.**
The port gains `find_active_by_id(person_id, expense_id) -> ExpenseEntity | None`, scoped to *owner + id +
live*. The use case treats `None` as `ExpenseNotFoundError`. This folds three failure modes (unknown id,
foreign owner, already-deleted) into one indistinguishable rejection, which is exactly what non-leaking
authorization requires.
- *Alternative considered:* `find_by_id(expense_id)` then compare `expense.person_id` in the use case. Rejected:
  it pulls another person's row into the application layer and tempts a leaky branch ("exists but not yours");
  scoping the query keeps the secret in the repository, mirroring `dissolve-pair`'s `find_active_by_person`.

**Soft-delete is a domain transition, stamped from the clock port — never `datetime.now()` in the domain.**
`ExpenseEntity.delete(at: datetime)` sets `self.deleted_at = at`. The use case obtains `at` from the
`ClockInterface` and passes it in, keeping the domain pure and deterministic under test (identical to how
`DissolvePairUseCase` stamps the dissolution).
- *Alternative considered:* a richer `delete()` that guards against double-deletion in the entity. Rejected:
  the scoped lookup already guarantees only live expenses reach `delete`, so an in-entity guard would be dead
  code; `delete` stays a single unconditional stamp, like `dissolve`.

**Add `list_including_removed` now, with this first soft-delete.**
CLAUDE.md defines soft-delete as "mistake recovery + **audit trail**", with `list_including_removed` as the
one method that sees everything. Introducing the audit read alongside the first soft-delete is what makes the
slice meaningfully testable (assert the row is gone from `find_in_range` yet present in the audit read) and
establishes the repository's two-read contract from the start.
- *Alternative considered:* defer the audit read to a later "list expenses" change. Rejected: without it, the
  spec's "survives for audit" half is unobservable and the soft-delete looks indistinguishable from a delete.

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
  exercised by this slice's tests; it is the natural primitive the later "list expenses" change will build on.
- **[Atomicity of stamp-then-persist is trivial in-memory but is two steps.]** → At this stage the entity and
  its persisted form are the same object; when the ORM lands, `delete(expense)` becomes a single row update
  inside the repository, preserving the one-transition contract.

## Migration Plan

Additive only — no existing behavior changes. New domain method, new error, three new port methods (two
extending reads, one mutating), one new use case + command. The in-memory `ExpenseRepository` implements the
new methods; existing `create`/`find_in_range`/`erase_for_person` are untouched. No data migration (pre-ORM).
Rollback is removal of the additive surface.

## Open Questions

- **Restore/undo** is deliberately out of scope. If product later wants it, it is its own capability that
  clears `deleted_at` under the same scoped-lookup authorization — noted here so the omission is intentional,
  not forgotten.
