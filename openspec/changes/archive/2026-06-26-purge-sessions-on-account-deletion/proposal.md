## Why

Deleting an account is the domain's nuclear, irreversible operation: it erases the person's ledger, retires
the account, and dissolves any live pair. But it currently leaves the person's **opaque server-side sessions
untouched** — `DeleteAccountUseCase` never reaches the session store. A token issued before deletion keeps
resolving against a retired account until it happens to expire, which is both a correctness gap (a "deleted"
person still has live auth state) and a security gap (the revocation the user expects from "delete my
account" silently does not happen for active sessions).

## What Changes

- Account deletion SHALL **purge all of the requester's sessions** as part of the same guarded cascade, so
  that no token survives the deletion.
- The session purge joins the existing independent effects (erase budgets, erase expenses, dissolve pair,
  retire person) in the use case's `asyncio.gather`, and like the pair-dissolve step it is **idempotent**: a
  person with zero sessions is a no-op, never an error.
- The session purge sits **after** the password guard, exactly like every other destructive effect — a
  failed guard revokes nothing.
- Add a `purge_for_person(person_id)` method to the existing `SessionRepositoryInterface` (sessions are owned
  by the `identity` context itself, so no cross-context bridge port is needed — unlike the budget/expense
  erasers). The in-memory adapter and the use-case wiring are updated; the contract stays async so the
  ORM-backed adapter slots in unchanged.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `delete-account`: add a requirement that deletion revokes/purges **all** of the person's sessions as part
  of the cascade — idempotent, and gated behind the same password guard.

## Impact

- **Spec**: `openspec/specs/delete-account/` gains one requirement (delta in this change).
- **Application**: `SessionRepositoryInterface` gains `purge_for_person`; `DeleteAccountUseCase` gains the
  session repository as a dependency and adds the purge to its `asyncio.gather`.
- **Infrastructure**: the in-memory session repository implements `purge_for_person`.
- **Composition root / wiring**: `DeleteAccountUseCase` is now constructed with the session repository.
- **Tests**: the `delete-account` integration test asserts sessions are gone after deletion; the fake
  session repository implements the new method; a unit test covers the no-sessions no-op.
- No change to `validate-session`, `sign-in`, `sign-out`, or any other context. No new dependency.
