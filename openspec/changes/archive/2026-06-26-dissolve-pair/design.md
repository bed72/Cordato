## Context

The pairing context can form a pair (`accept-invite-code`) and render the couple-level reads on top of it
(`couple-expenses`, `couple-budget`), all keyed off the pairing invariant *"a person is in ≤1 pair with
`deleted_at = null`"*. The `PairEntity` already carries `deleted_at` (null = live; stamped = dissolved) and
the `PairRepositoryInterface.find_active_by_person` already excludes soft-deleted pairs. So the storage
shape and the read path for "no live pair" already exist — what is missing is the single transition that
**moves** a pair from live to dissolved. This change adds exactly that transition, nothing more.

The build stage is still pre-ORM/pre-web: the slice runs in-memory behind the existing ports, with the
real `Clock` gateway supplying the timestamp.

## Goals / Non-Goals

**Goals:**
- Add the one transition out of the live state: stamp `Pair.deleted_at` and persist it.
- Keep authorization intrinsic — resolve the pair *by the requester*, so a person can only dissolve their
  own live pair, with no extra authorization machinery.
- Prove *"reversible without loss"*: dissolve writes one field and touches nothing else; re-pairing
  afterward forms a fresh pair.
- Stay faithful to the existing pairing patterns (entity mutation mirrors `consume`; repo method mirrors
  `consume`; reuse `NotPairedError`).

**Non-Goals:**
- `delete-account` (hard-delete) — it will *compose* this dissolve later; out of scope here.
- Any notification on dissolve, re-invite flow change, pagination, HTTP handler, or ORM model/mapper.
- A read-model/output for the command — dissolve returns nothing.

## Decisions

### 1. `PairEntity.dissolve(at)` mirrors `InviteCodeEntity.consume(at)` — a bare stamp, no defensive guard

The entity gains `def dissolve(self, at: datetime) -> None: self.deleted_at = at`. It does **not** guard
against an already-dissolved pair. This is deliberate and consistent with `consume`, which also stamps
without re-checking: the live-state guard lives at the **use-case boundary**, because the only way to
obtain a pair to dissolve is `find_active_by_person`, which returns live pairs exclusively. An
already-dissolved pair is therefore unreachable through the use case — it manifests one level up as
`NotPairedError` ("you are in no live pair"), which is the truthful, non-leaking statement.

- *Alternative considered:* add a `PairAlreadyDissolvedError` and guard inside `dissolve`. Rejected: the
  guarded branch is unreachable via the only caller, so it would be a new one-concept-per-file error for a
  path no test can legitimately exercise through the public flow — over-engineering, and it diverges from
  the established `consume` pattern. The boundary guard (`NotPairedError`) already covers it.

`deleted_at` is already a mutable field on the `slots=True, eq=False` dataclass, so the mutation needs no
new field and identity equality (by `id`) is unaffected.

### 2. Extend `PairRepositoryInterface` with `dissolve(pair)`, mirroring `consume(invite_code)`

Persisting a just-stamped state change is its own verb in this codebase (`InviteCodeRepository.consume`),
not a generic `update`/`save`. So the port gains `async def dissolve(self, pair: PairEntity) -> None` —
"persist a pair whose `deleted_at` has just been stamped". The in-memory adapter re-stores by id
(`self._pairs[pair.id] = pair`).

- *Alternative considered:* a generic `update(pair)` or `save(pair)`. Rejected: verb-named, intent-revealing
  persistence methods are the local idiom (`consume`); a generic `update` says less and invites misuse.

### 3. Authorization is the lookup, not a separate check

The use case calls `find_active_by_person(requester_id)`. By contract that returns only a live pair the
requester is a member of, so "is the requester allowed to dissolve this pair?" is answered structurally by
*which pair the lookup returns*. There is no pair id taken from the caller, hence no way to target someone
else's pair. This keeps per-person authorization intact with zero extra code.

### 4. The use case returns `None` — dissolve is a pure command

The only outcomes are "the live pair is now dissolved" or `NotPairedError`. There is no meaningful
read-model (the result is the *absence* of the shared view), so `execute` returns `None` and there is **no
output mapper** — consistent with "a value object / mapper must earn its existence". Input is a minimal
`DissolvePairData(requester_id: str)` command.

### 5. Flow (async, guard-before-work)

```
DissolvePairData(requester_id)
  → pair = await pair_repository.find_active_by_person(requester_id)
  → if pair is None: raise NotPairedError()          # guard before any further work
  → now = await clock.now()
  → pair.dissolve(now)                               # pure domain mutation
  → await pair_repository.dissolve(pair)             # persist
  → return None
```

The two awaited calls have a real data dependency (the second needs the resolved pair, the timestamp needs
nothing but is cheap), and the guard short-circuits before the clock call, so they are awaited
sequentially — no `asyncio.gather` is warranted here (there is no pair of mutually independent I/O calls to
overlap after the guard).

## Risks / Trade-offs

- **Concurrent double-dissolve** (two requests dissolving the same live pair at once) → both could read the
  pair live and stamp it. The outcome is identical and idempotent in effect (same pair ends dissolved; the
  second timestamp simply overwrites), and the in-memory stage is single-process. Mitigation deferred to
  the ORM stage, where the persistence adapter can enforce a conditional update / optimistic check behind
  the unchanged `dissolve` port — no domain or use-case change needed.
- **No audit of *who* dissolved** → the `Pair` records only that it was dissolved (`deleted_at`), not which
  member triggered it. That is sufficient for the current model (both members are symmetric and either may
  dissolve); if an audit trail is later wanted, it is an additive change, not a reshape.
- **`delete-account` will need the same transition** → by shipping `dissolve` as a reusable entity method +
  port now, account deletion later composes it (dissolve any live pair as a consequence) instead of
  re-implementing the stamp. Slight risk of premature generality — mitigated by the fact that the method is
  the minimal, already-needed transition, not speculative surface.

## Open Questions

- None blocking. (Whether dissolve should emit a `pair_dissolved` notification is a future concern, tied to
  the parked notification-triggering work — explicitly out of scope here.)
