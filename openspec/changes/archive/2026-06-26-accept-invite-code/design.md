## Context

`create-invite-code` mints a single-use token but nothing redeems it, so the `Pair` — the keystone the
entire shared couple view depends on — does not yet exist. This change is the second pairing slice:
**accepting** a code to form the pair. It follows the established pattern of every prior slice (pure
`domain/`, async ports in `application/`, in-memory / gateway adapters in `infrastructure/`, fully testable
without a web framework or ORM) and reuses the `core/` determinism ports as-is.

The one genuinely new architectural question is the requirement *"both parties must be active people"*:
it needs a fact owned by the `identity` context, yet the modular monolith forbids a `pairing → identity`
import. The design resolves this with a consumer-owned anti-corruption port, mirroring exactly why the
determinism ports were lifted into `core/` rather than imported across contexts.

## Goals / Non-Goals

**Goals:**
- Add `AcceptInviteCodeUseCase` and the `PairEntity` so redeeming a valid code atomically consumes it and
  forms the live pair.
- Enforce every redemption invariant as a domain rule with a pt-BR non-leaking error: unknown / expired /
  consumed code, self-pairing, either party already in a live pair, either party inactive.
- Verify the active-person rule **without coupling `pairing` to `identity`** — via a port pairing owns.
- Ship a runnable vertical slice: in-memory `PairRepository`, the extended in-memory
  `InviteCodeRepository`, and a fake `PersonDirectory` for tests.

**Non-Goals:**
- **dissolve-pair** (soft-deleting a live pair) and the couple views (couple budget / couple expenses).
- The real identity-backed `PersonDirectory` adapter and its composition-root wiring (no app bootstrap
  exists yet).
- Revoking/listing codes; capping active codes per person; any web handler; any ORM model/mapper.

## Decisions

**1. `PairEntity` — a thin, money-less link, born live via its factory.**
`features/pairing/domain/entities/pair_entity.py`. Fields: `id`, `created_at`, `person_a_id` (the
creator), `person_b_id` (the accepter), `deleted_at: datetime | None`. `PairEntity.create(...)` is the
only sanctioned constructor — it receives `id`, `created_at`, `person_a_id`, `person_b_id` and fixes
`deleted_at = None` (no default on the field, mirroring `PersonEntity`/`InviteCodeEntity`, so the bare
constructor cannot birth a live pair; the explicit constructor stays for future rehydration). Equality by
`id` (`__eq__`/`__hash__`). The pair owns no money, no budget, no expense — by deliberate domain design.
Ordering convention: creator is always `person_a_id`, accepter `person_b_id`.

**2. Redemption validity lives in `InviteCodeEntity`, not the use case.**
The code's own state decides whether it can be redeemed, so the checks are domain methods on the entity:
`is_expired(reference: datetime) -> bool` (`reference >= expires_at`), `is_consumed -> bool` (`consumed_at
is not None`), and a `consume(at: datetime)` mutator that sets `consumed_at = at`. The use case calls
these and raises the pairing errors; keeping the predicates in the domain (not inline date math in the use
case) matches *"keep money/date math in the domain"*. `consume` mutates in place (the entity is the live
aggregate the repository then persists).

**3. Active-person check via a consumer-owned port — never a cross-module import.**
`pairing` defines `PersonDirectoryInterface` in `features/pairing/application/interfaces/` —
`async def is_active(person_id: str) -> bool`. This is pairing's anti-corruption seam over "the people
directory": pairing speaks its own vocabulary and depends only on this ABC. The concrete adapter that
satisfies it by reading identity's store is wired at the **composition root** (the only layer permitted to
know both modules) and is **deferred** alongside the absent app bootstrap — exactly the "deferred, not
skipped" stance already applied to web/ORM. For the runnable slice, a hand-written `FakePersonDirectory`
satisfies the port in tests. This is the same principle that moved the determinism ports into `core/`:
shared facts cross contexts through an owned abstraction, never through a direct feature-to-feature
dependency. Returning a bare `bool` (not raising) keeps the port free of pairing's domain errors; the use
case translates `False` into `PersonNotActiveError`.

**4. Repository ports grow; soft-delete is the repository's job.**
- `InviteCodeRepositoryInterface` gains `find_by_token(code: str) -> InviteCodeEntity | None` (the lookup
  that resolves the supplied token) and `consume(invite_code: InviteCodeEntity) -> None` (persist the
  now-stamped code). The minting `create` is untouched.
- New `PairRepositoryInterface`: `find_active_by_person(person_id: str) -> PairEntity | None` — returns
  only a **live** pair (`deleted_at` null), the repository owning the soft-delete filter — and
  `create(pair: PairEntity) -> None`. A person is in ≤1 live pair, so returning a single optional pair is
  correct.

**5. The use case: guard hard, then form the pair.**
`AcceptInviteCodeUseCase(clock, identifier, invite_code_repository, pair_repository, person_directory)`.
Order, with every short-circuiting guard **before** any expensive/independent work, per the async rules:
  1. `find_by_token(code)` → if `None`, raise `InviteCodeNotFoundError`.
  2. Read `now` from the clock; if `code.is_expired(now)` → `InviteCodeExpiredError`; if `code.is_consumed`
     → `InviteCodeAlreadyConsumedError`.
  3. If `accepter_id == code.creator_id` → `SelfPairingError` (a pure check, no I/O — cheapest, but it
     needs the resolved code, so it sits here).
  4. The remaining reads are mutually independent → issue together with `asyncio.gather`:
     `pair_repository.find_active_by_person(creator_id)`,
     `pair_repository.find_active_by_person(accepter_id)`,
     `person_directory.is_active(creator_id)`, `person_directory.is_active(accepter_id)`,
     `identifier.generate()`. If either pair lookup returns a live pair → `AlreadyPairedError`; if either
     `is_active` is `False` → `PersonNotActiveError`. (`now` was already drawn in step 2 for the expiry
     guard; the fresh `id` is gathered here since it is needed only on the success path.)
  5. `code.consume(now)`; build `PairEntity.create(id=..., created_at=now, person_a_id=creator_id,
     person_b_id=accepter_id)`; persist both via `invite_code_repository.consume(code)` and
     `pair_repository.create(pair)`; return `PairDataMapper.to_data(pair)`.

The two persistence writes are independent and may be gathered; **atomicity** across them is a known
in-memory limitation (no transaction without the ORM) — recorded under Risks, to be a single transaction
when persistence lands.

**6. Errors — pt-BR, non-leaking, one file each.**
Under `features/pairing/domain/errors/`, one class per file: `InviteCodeNotFoundError`
("Convite inválido."), `InviteCodeExpiredError` ("Convite expirado."), `InviteCodeAlreadyConsumedError`
("Convite já utilizado."), `SelfPairingError` ("Você não pode parear consigo mesmo."), `AlreadyPairedError`
("Já existe um par ativo.") — deliberately silent on *which* party — and `PersonNotActiveError`
("Conta indisponível.") — silent on *which* party and never echoing an id. None leaks an existence fact.

**7. Data shapes named by nature.**
`AcceptInviteCodeData` (command — `code: str`, `accepter_id: str`), `PairData` (read-model — `id`,
`person_a_id`, `person_b_id`, `created_at`), `PairDataMapper.to_data(pair)`. No `in`/`out` naming; web
request/response shapes are deferred with the framework.

**8. In-memory adapters now; no model/mapper yet.**
In-memory `PairRepository` (a dict keyed by `id`, `find_active_by_person` scanning for a live pair
containing the person) and the extended in-memory `InviteCodeRepository` (`find_by_token` scans by token;
`consume` overwrites the stored entity). No `PairModel` / `InviteCodeModel` until an ORM is chosen.

## Risks / Trade-offs

- **Cross-write atomicity (consume + create pair).** Without an ORM/transaction, the two writes are not
  atomic; a crash between them could consume a code without forming the pair. Accepted for the in-memory
  stage; becomes one transaction when persistence lands. The single-use guard means the worst case is a
  burned code, never a double pair.
- **TOCTOU on the ≤1-live-pair invariant.** The pair-existence check then create is not concurrency-safe
  in memory; the same person could in theory race into two pairs. Same resolution path as identity's
  email-uniqueness TOCTOU: a DB constraint (partial unique index on live pairs) when the ORM lands. No
  concurrency in the in-memory adapter today.
- **Deferred real `PersonDirectory` adapter.** The active-person rule is fully specified and exercised via
  a fake, but the production adapter (and its composition-root wiring to identity) lands with the app
  bootstrap. The port and its contract exist now, so wiring later touches no domain or use-case code.
- **`AlreadyPairedError` / `PersonNotActiveError` are intentionally vague.** They never say which party is
  paired or inactive — avoiding a couple-membership / account-status enumeration oracle. The cost is a
  less specific message, accepted per the non-leaking error rule.
