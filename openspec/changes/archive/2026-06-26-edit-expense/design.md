## Context

`features/expenses` already supports recording, reading (list + range-derivation), and soft-delete of
expenses. The pieces this slice builds on are all in place:

- `ExpenseEntity` (`domain/entities/expense_entity.py`) — `create(...)` validates `amount.value > 0`
  and normalizes the description (`description.strip() or None`); `delete(at)` stamps `deleted_at`;
  equality is by `id`.
- `ExpenseRepositoryInterface` (`application/interfaces/`) — already has `find_active_by_id(person_id,
  expense_id)`, the owner-scoped, soft-delete-excluding lookup used by delete.
- `DeleteExpenseUseCase` — the authorization-via-lookup template: `find_active_by_id` → `None` →
  `ExpenseNotFoundError`, guard before any mutation.
- `CreateExpenseUseCase` — the build/validate/persist/return-`ExpenseDataMapper.to_data` template.
- Output `ExpenseData` + `ExpenseDataMapper` already exist and are reused verbatim.

Editing is the missing CRUD arm. It is the create-flow's amount/description validation plus the
delete-flow's authorization-via-lookup, joined — and nothing else, because an expense has no range and
therefore no non-overlap invariant (the budget edit's overlap check has no counterpart here).

## Goals / Non-Goals

**Goals:**
- Edit a live, owned expense in place (`amount`, `occurred_on`, `description`), preserving `id` and
  `created_at`.
- Authorization is the lookup — same indistinguishable `ExpenseNotFoundError` for unknown / foreign /
  soft-deleted, as in delete.
- Re-validate amount and normalize the description in the entity, exactly as `create` does.
- Touch no budget — prove derive-don't-store once more.
- Reuse every existing error and the `ExpenseData` output; add no new error type.

**Non-Goals:**
- No non-overlap / range validation — an expense is a single-day fact with no siblings invariant.
- No partial/patch semantics — the command carries the full set of editable fields (PUT-style). See the
  decision below.
- No `updated_at` / edit-auditing on the entity (would change the stored shape — a separate change).
- No `Model`/`ModelMapper` (ORM still deferred); ships against the in-memory adapter.
- No change to budgeting, the active/default derivations, or any other context.

## Decisions

**1. Entity grows an `ExpenseEntity.edit(...)` mutation method, mirroring `create`'s validation.**
It re-runs the same guard (`amount.value > 0` → `InvalidAmountError`), normalizes the description
(`description.strip() or None`), and overwrites the three editable fields in place. `id`, `person_id`,
`created_at`, and `deleted_at` are left untouched. Keeping validation in the entity (not the use case)
keeps the illegal-state guard where `create` already put it. There is no repository-dependent check to
keep out of the entity (no overlap), so the entity carries the whole rule.

**2. `EditExpenseUseCase` orders the steps guard-first, then validate-and-mutate, then persist.**
```
expense = await repo.find_active_by_id(requester_id, expense_id)   # authorization == lookup
if expense is None: raise ExpenseNotFoundError()
expense.edit(amount=MoneyValueObject(data.amount), occurred_on=…, description=…)  # amount guard + normalize
await repo.update(expense)
return ExpenseDataMapper.to_data(expense)
```
No `list_*` fetch, no overlap filter — strictly simpler than the budget edit. The guard runs before any
mutation, so a rejected authorization changes nothing.

**3. New repository method `update(expense)` — distinct name from `create`/`delete`.**
In-memory all three are `self._expenses[expense.id] = expense`, but the port states intent: `create`
introduces, `delete` persists a soft-deleted state, `update` persists a mutated live state. A separate
method keeps the contract honest for the eventual ORM adapter (an UPDATE, not an INSERT). It is added to
`ExpenseRepositoryInterface` and the in-memory `ExpenseRepository`.

**4. `EditExpenseData` carries the full editable field set + the requester.**
`requester_id: str`, `expense_id: str`, `amount: Decimal`, `occurred_on: date`, `description: str |
None` — a frozen, slotted dataclass like `CreateExpenseData`/`DeleteExpenseData`. Full-replacement (not
patch) because partial edits force `Optional`-vs-absent sentinels ("did they clear the description or
omit it?") that buy nothing at this layer; the web layer can offer patch ergonomics later by reading
current values first. This matches the shape of `CreateExpenseData`.

**5. No clock dependency.** Since we deliberately add no `updated_at`, `EditExpenseUseCase` needs no
clock — there is no timestamp to stamp. It depends only on `ExpenseRepositoryInterface`. (Contrast
delete, which needs the clock to stamp `deleted_at`.) Fewer collaborators, matching the no-`updated_at`
decision.

**6. No new error.** The two rejections map onto existing errors: not-found → `ExpenseNotFoundError`,
bad amount → `InvalidAmountError`. Both carry pt-BR, non-leaking messages already.

## Risks / Trade-offs

- **Full-replacement vs patch.** A caller that wants to change only the amount must resend the
  unchanged day/description. Accepted: avoids sentinel complexity at the `data` layer; the web layer
  owns patch ergonomics when it lands.
- **No edit trail.** Without `updated_at`, an audit cannot tell an edited expense from an untouched one.
  Accepted for this slice — adding edit-auditing changes the entity's stored shape and belongs to its
  own change.
- **`update` vs reusing `delete`/`create` persistence.** Slightly more surface on the port, but the
  honest naming pays off the moment the ORM adapter distinguishes INSERT from UPDATE.
- **Derive-don't-store, re-proven.** The chief value of this slice is negative: it adds an edit that
  moves an expense across budget boundaries while touching no budget. The integration test asserts that
  storage holds no budget mutation and only the next read regroups — the same proof the budget edit
  made from the other side.
