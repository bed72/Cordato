## Context

`features/budgeting` already supports create, read (active + default), and soft-delete of budgets. The
pieces this slice builds on are all in place:

- `BudgetEntity` (`domain/entities/budget_entity.py`) — `create(...)` validates `amount > 0` and
  `start_date <= end_date`; `overlaps(other)` and `covers(day)` express the inclusive-range rules;
  equality is by `id`.
- `BudgetRepositoryInterface` (`application/interfaces/`) — already has `find_active_by_id(person_id,
  budget_id)` (the owner-scoped, soft-delete-excluding lookup used by delete) and
  `list_live_for_person(person_id)` (the set the non-overlap check runs against).
- `CreateBudgetUseCase` — the template: build/validate, fetch `list_live_for_person`, reject on any
  `overlaps`, persist, return `BudgetDataMapper.to_data(budget)`.
- `DeleteBudgetUseCase` — the authorization-via-lookup template: `find_active_by_id` → `None` →
  `BudgetNotFoundError`, guard before any mutation.
- Output `BudgetData` + `BudgetDataMapper` already exist and are reused verbatim.

Editing is the missing CRUD arm. It is the create-flow's invariants (amount, range, non-overlap) plus
the delete-flow's authorization-via-lookup, joined.

## Goals / Non-Goals

**Goals:**
- Edit a live, owned budget in place (`amount`, `start_date`, `end_date`, `note`), preserving `id` and
  `created_at`.
- Authorization is the lookup — same indistinguishable `BudgetNotFoundError` for unknown / foreign /
  soft-deleted, as in delete.
- Re-validate amount and range in the entity; re-validate non-overlap in the use case, **excluding the
  edited budget from its own check**.
- Touch no expense — prove derive-don't-store once more.
- Reuse every existing error and the `BudgetData` output; add no new error type.

**Non-Goals:**
- No partial/patch semantics — the command carries the full set of editable fields (PUT-style). See the
  decision below.
- No `updated_at` / edit-auditing on the entity (would change the stored shape — a separate change).
- No `Model`/`ModelMapper` (ORM still deferred); ships against the in-memory adapter.
- No change to expenses, the active/default derivations, or any other context.

## Decisions

**1. Entity grows a `BudgetEntity.edit(...)` mutation method, mirroring `create`'s validation.**
It re-runs the same two guards (`amount.value > 0` → `InvalidBudgetAmountError`; `start_date <= end_date`
→ `InvalidBudgetRangeError`), normalizes the note (`note.strip() or None`), and overwrites the four
editable fields in place. `id`, `person_id`, `created_at`, and `deleted_at` are left untouched. Keeping
validation in the entity (not the use case) keeps the illegal-state guard where `create` already put it.
The non-overlap check stays *out* of the entity — it needs the repository, so it lives in the use case,
exactly as in `CreateBudgetUseCase`.

**2. `EditBudgetUseCase` orders the steps guard-first, then validate, then overlap, then persist.**
```
budget = await repo.find_active_by_id(requester_id, budget_id)   # authorization == lookup
if budget is None: raise BudgetNotFoundError()
budget.edit(amount=MoneyValueObject(data.amount), start_date=…, end_date=…, note=…)  # amount/range guards
others = await repo.list_live_for_person(requester_id)
if any(budget.overlaps(o) for o in others if o.id != budget.id): raise OverlappingBudgetError()
await repo.update(budget)
return BudgetDataMapper.to_data(budget)
```
The `o.id != budget.id` filter is the crux: the edited budget is in the live set and would otherwise
overlap itself. Because `BudgetEntity.__eq__` is by id, `o != budget` reads equivalently; the explicit
`o.id != budget.id` is chosen for unmistakable intent in the spec-critical line.

**3. New repository method `update(budget)` — distinct name from `create`/`delete`.**
In-memory all three are `self._budgets[budget.id] = budget`, but the port states intent: `create`
introduces, `delete` persists a soft-deleted state, `update` persists a mutated live state. A separate
method keeps the contract honest for the eventual ORM adapter (an UPDATE, not an INSERT). It is added to
`BudgetRepositoryInterface` and the in-memory `BudgetRepository`.

**4. `EditBudgetData` carries the full editable field set + the requester.**
`requester_id`, `budget_id`, `amount: Decimal`, `start_date: date`, `end_date: date`, `note: str | None`
— a frozen, slotted dataclass like `CreateBudgetData`/`DeleteBudgetData`. Full-replacement (not patch)
because partial edits force `Optional`-vs-absent sentinels ("did they clear the note or omit it?") that
buy nothing at this layer; the web layer can offer patch ergonomics later by reading current values
first. This matches the shape of `CreateBudgetData`.

**5. Clock is injected but only `now()`-free here — there is no timestamp to stamp.**
Since we deliberately add no `updated_at`, `EditBudgetUseCase` needs no clock at all. It depends only on
`BudgetRepositoryInterface`. (Contrast delete, which needs the clock to stamp `deleted_at`.) Fewer
collaborators, matching the no-`updated_at` decision.

**6. No new error.** The four rejections map onto existing errors: not-found → `BudgetNotFoundError`,
bad amount → `InvalidBudgetAmountError`, inverted range → `InvalidBudgetRangeError`, overlap →
`OverlappingBudgetError`. All carry pt-BR, non-leaking messages already.

## Risks / Trade-offs

- **Self-overlap bug surface.** Forgetting to exclude the edited budget from its own non-overlap check
  would make every edit-in-place fail. Mitigated by the explicit `o.id != budget.id` filter and a
  dedicated test scenario ("re-saving the same budget does not overlap itself").
- **Full-replacement vs patch.** A caller that wants to change only the amount must resend the
  unchanged dates/note. Accepted: avoids sentinel complexity at the `data` layer; the web layer owns
  patch ergonomics when it lands.
- **No edit trail.** Without `updated_at`, an audit cannot tell an edited budget from an untouched one.
  Accepted for this slice — adding edit-auditing changes the entity's stored shape and belongs to its
  own change.
- **`update` vs reusing `delete`/`create` persistence.** Slightly more surface on the port, but the
  honest naming pays off the moment the ORM adapter distinguishes INSERT from UPDATE.
