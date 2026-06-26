## Context

`delete-account` is the domain's only **physical** deletion and its first **cross-module destructive**
operation. The use case is born in `identity`, but its effects land in three other contexts: it erases
`budgeting` and `expenses` data and dissolves a `pairing` link. The modular monolith forbids
`identity -> budgeting/expenses/pairing` imports, and the architecture forbids non-determinism in the
domain. The codebase already has the exact precedent to follow: `pairing` reaches `identity` only through
its own anti-corruption ports (`PersonDirectoryInterface`, `PartnerBudgetReaderInterface`,
`PartnerExpenseReaderInterface`), whose composition-root bridge adapters are deferred with the web/ORM while
tests drive the ports with hand-written fakes. This change mirrors that precedent in the opposite direction.

Current relevant state:
- `PersonEntity` carries `status` (`PersonStatus.ACTIVE | DELETED`) and `email` (`EmailValueObject`) — both
  fields already exist; no schema growth is needed for retirement.
- `PasswordHasherInterface` hashes but cannot **verify**; the Argon2 gateway wraps its sync call off-loop.
- `PersonRepositoryInterface` can look a person up by email and create one, but cannot fetch by id or persist
  a mutation.
- `BudgetRepositoryInterface` / `ExpenseRepositoryInterface` create and read, but have no physical purge.
- `PairEntity.dissolve` + `PairRepositoryInterface.dissolve` + `find_active_by_person` already exist
  (`dissolve-pair`).
- Web/ORM/session are deferred; the slice is in-memory + the real Argon2 gateway.

## Goals / Non-Goals

**Goals:**
- One guarded, irreversible operation: verify password → erase ledger → retire account + neutralize email →
  dissolve live pair, in that order, with the password guard strictly first.
- Keep `identity`'s domain and use case dependent only on `identity` ports; no outward module import.
- Reuse the dissolve building block rather than re-implementing it — but idempotently.
- Ship a runnable, fully-tested in-memory slice.

**Non-Goals:**
- Session/token invalidation (no auth port exists yet — enters with the web layer behind a new port).
- The composition-root bridge adapters and the real DB transaction (deferred with web/ORM, like the existing
  partner readers).
- Any "soft account deletion" / restore / undo — deletion is physical and final by design.
- Notifications, HTTP handler, ORM model/mapper.

## Decisions

### 1. Password re-confirmation = extend `PasswordHasherInterface` with `verify`, not a new port

The hasher already owns the algorithm; verification is the same algorithm's other half (Argon2's
`verify`). Adding `verify(password: PasswordValueObject, hash: str) -> bool` keeps the secret-handling in one
adapter, off-loop like `hash`. Alternative — a separate `PasswordVerifierInterface` — splits one cohesive
responsibility across two ports for no gain (there is no world where you swap the hasher but not the
verifier). The use case resolves the requester via a new `PersonRepository.find_active_by_id`, reads the
stored hash, and calls `verify`; a `False` raises `IncorrectPasswordError`. The error is pt-BR and
non-leaking (`"Senha incorreta."`); since the requester is acting on *their own* account, naming the wrong
factor is not account enumeration.

### 2. `PersonEntity.delete()` is one domain transition; the sentinel email is derived in the domain

`delete()` flips `status` to `DELETED` and replaces `email` with a sentinel derived from the id. The
derivation is a **domain rule** (the neutralized address is part of what "deleted" means), so it lives in the
entity, not in a mapper or the use case. The sentinel is `EmailValueObject(f"deleted+{id}@{DELETED_EMAIL_DOMAIN}")`
— `deleted+<id>@…` is collision-free (id is unique) and passes the email regex. The exact reserved domain
(e.g. `trocado.invalid`, per RFC 2606) is a module-level constant in the entity file. Mirrors
`PairEntity.dissolve` / `InviteCodeEntity.consume`: a small, factory-guarded state change, no new field.

### 3. Cross-module effects via three identity-owned anti-corruption ports

`identity/application/interfaces/` gains, in identity's own vocabulary:
- `BudgetEraserInterface.erase_for_person(person_id) -> None`
- `ExpenseEraserInterface.erase_for_person(person_id) -> None`
- `PairDissolverInterface.dissolve_for_person(person_id) -> None` — **idempotent** (no-op when no live pair)

The use case depends only on these. The concrete bridges (budget eraser → `budgeting`'s repo, pair dissolver
→ `pairing`'s `find_active_by_person` + `dissolve`) are composition-root adapters, **deferred** like the
existing partner readers; tests provide `fake_budget_eraser`, `fake_expense_eraser`, `fake_pair_dissolver`.
This is symmetric to how `pairing` already consumes `identity`, so it adds no new architectural pattern.

Why ports (not letting the use case import the other repos): the dependency rule and modular-monolith
boundary. Why a *dissolver* port instead of reusing `DissolvePairUseCase` directly across modules: the
cross-module seam must be an `identity` abstraction, and the consequence here is **idempotent** (no
`NotPairedError`), unlike the standalone dissolve use case — so the bridge adapter swallows "not paired"
into a no-op.

### 4. Physical purge primitives on the budget/expense repositories

`BudgetRepositoryInterface` and `ExpenseRepositoryInterface` each gain
`erase_for_person(person_id) -> None`: a **physical** delete of every row owned by the person (live and
soft-deleted alike) — distinct from the soft-delete used day-to-day. This is the cascade's primitive and the
only physical delete those repos expose. The in-memory adapters drop all matching entries. The composition-
root budget/expense **eraser** adapters delegate to this method; keeping the purge in the repository (not in
the eraser adapter) keeps storage knowledge inside the persistence layer.

### 5. Orchestration order and atomicity at the in-memory stage

Order in `DeleteAccountUseCase`:
1. `find_active_by_id(requester_id)` → if `None`, raise `IncorrectPasswordError` (no oracle: an unknown/
   non-active id and a wrong password fail identically).
2. `verify(password, person.password)` → `False` raises `IncorrectPasswordError`. **Guard ends here.**
3. After the guard, the destructive steps are mutually **independent** (erase budgets, erase expenses,
   retire the person via `delete()` + `PersonRepository.delete`, dissolve the live pair) → issue them with
   `asyncio.gather` per the async-everywhere rule.
4. Return `None`.

The spec calls the operation *indivisible*. There is no transaction manager in-memory, so true atomicity is
**deferred**: the design records that, when the ORM lands, the four port calls run inside a single DB
transaction behind the same ports — no change to `domain/` or `application/`. The guard-first ordering means
the only failure that can occur before any mutation (a wrong password) leaves everything untouched today.

## Risks / Trade-offs

- **Non-atomic in-memory cascade** → a mid-cascade crash could leave a partially-erased ledger. Mitigation:
  guard runs strictly first (the common rejection path mutates nothing); full atomicity arrives with the ORM
  transaction behind the unchanged ports; in-memory steps are simple and non-failing.
- **Sentinel-email collision or invalidity** → a malformed `deleted+<id>@…` would raise `InvalidEmailError`.
  Mitigation: the id is a uuid7 string with no `@`/whitespace, and the reserved domain is fixed, so the
  sentinel always matches the email regex and is unique per person.
- **Erasing the wrong scope** → a buggy `erase_for_person` could over-delete. Mitigation: the port takes a
  single `person_id`; tests assert a second person's ledger and the partner's data are untouched.
- **`verify` leaking timing/secrets** → mitigation: Argon2's constant-time verify, run off-loop, never
  logging the plaintext (same adapter contract as `hash`).
- **Deferred session invalidation** → a still-valid session could outlive the account until the web layer
  lands. Accepted: documented as out of scope; the account no longer authenticates (`status = deleted`), and
  session revocation enters behind its own port without touching this use case.
