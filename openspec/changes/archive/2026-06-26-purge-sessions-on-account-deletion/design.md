## Context

`DeleteAccountUseCase` runs the domain's only physical deletion as a guarded cascade: verify the password
first, then issue four mutually-independent effects together via `asyncio.gather` — erase budgets, erase
expenses, dissolve the live pair, retire the person. The session-lifecycle slice (already shipped) introduced
opaque server-side sessions behind `SessionRepositoryInterface` (`create` / `find_valid_by_token` / `revoke`),
where validity (not revoked, not expired) is the repository's responsibility.

The cascade never touches that store, so a token issued before deletion keeps resolving until it expires.
This change closes that hole by adding session purge as a fifth effect of the cascade. It was already flagged
as known follow-up work.

## Goals / Non-Goals

**Goals:**
- After a successful account deletion, none of the person's sessions resolves.
- The purge obeys the cascade's existing shape: behind the password guard, idempotent, issued in the
  `gather` with the other independent effects.
- The contract stays async so the eventual ORM adapter slots in behind the same port.

**Non-Goals:**
- No change to how sessions are issued, validated, or individually revoked (`sign-in`, `sign-out`,
  `validate-session` are untouched).
- No new entity, value object, or cross-context port.
- No transaction manager — atomicity remains the ORM-stage concern, exactly as for the rest of the cascade
  today.

## Decisions

**1. Extend the existing `SessionRepositoryInterface` rather than introduce an eraser/bridge port.**
Budgets and expenses are owned by *other* contexts, so identity reaches them through dedicated bridge ports
(`BudgetEraserInterface`, `ExpenseEraserInterface`) and the pair through `PairDissolverInterface`, honoring
the modular-monolith no-cross-import rule. **Sessions are owned by `identity` itself** — the entity, the port,
and the adapter all live here — so there is no boundary to bridge. Adding `purge_for_person(person_id)` to
the existing `SessionRepositoryInterface` is the honest model; inventing a `SessionPurgerInterface` would be
ceremony over a boundary that does not move. *Alternative considered:* a separate purger port for symmetry
with the erasers — rejected by the project's "symmetry is not a reason" rule.

**2. Purge (physically delete), not revoke.** Account deletion already physically erases the ledger; sessions
are pure ephemeral auth state, not audit-worthy ledger data, and the account they point to is being retired.
Physically removing them leaves no dangling rows referencing a retired person and matches the nuclear,
no-restore nature of the operation (and the "purge" verb in the flagged follow-up). *Alternative considered:*
stamp `revoked_at` on each (consistent with `sign-out`) — rejected: it keeps rows pointing at a destroyed
account for no audit benefit, since the rest of the cascade keeps no audit trail either.

**3. `purge_for_person` takes only `person_id` and needs no `now`.** Unlike `find_valid_by_token`, the purge
removes *all* of the person's sessions regardless of validity — both live and already-expired/revoked rows —
so it is independent of the clock and stays trivially deterministic. This mirrors the erasers, which take
just the `person_id`.

**4. Keep it inside the existing `gather`, behind the guard.** The purge is independent of the other four
effects (no effect consumes another's result), so it joins them in the single `asyncio.gather` after the
password check — preserving the "guard pays for no destructive work" property and the async-maybe-I/O
contract.

## Risks / Trade-offs

- **[No transaction at the in-memory stage]** → A partial failure mid-`gather` could leave some effects
  applied and others not. This is the *existing* property of the whole cascade, not introduced here;
  atomicity arrives with the ORM behind these same ports. The purge adds no new exposure.
- **[Physical delete loses any session audit trail]** → Accepted: account deletion is explicitly the domain's
  irreversible, no-audit operation; session rows for a retired account have no audit value.

## Migration Plan

Pure additive change to an in-memory slice: add the port method, implement it in the in-memory adapter and
the test fake, inject the session repository into `DeleteAccountUseCase`, and add it to the `gather`. No data
migration, no rollback concern (no persisted store yet). The composition root / wiring gains one constructor
argument.

## Open Questions

None.
