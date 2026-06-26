## Context

`accept-invite-code` brought the `Pair` into existence but renders nothing through it. This change is the
first **couple-level read**: the `couple-expenses` view — the union of both partners' live expenses, each
marked from the reader's perspective (`mine` / `theirs`). It follows every prior slice's pattern (pure
`domain/`, async ports in `application/`, in-memory / gateway adapters, fully testable without web/ORM) and
reuses the existing `PairRepository` as-is.

Two architectural questions are already settled by precedent and are simply applied here:
1. **Reading another context's data** (expenses) without a `pairing → expenses` import — resolved exactly
   as budgeting reads spend via its own `SpendReaderInterface` and as pairing already checks activity via
   `PersonDirectoryInterface`: a consumer-owned anti-corruption **gateway** port.
2. **Where the derived read-time view lives** — a **Virtual Object** (`domain/virtual_objects/`), the third
   domain shape, exactly like `ActiveBudgetVirtualObject`: it composes stored state and derives a value,
   has no identity, and is never persisted.

So the genuinely new modeling here is small and well-bounded: a `Perspective` enum, a
`CoupleExpenseVirtualObject` that derives it, a `NotPairedError`, and a read use case that unions two
ledgers.

## Goals / Non-Goals

**Goals:**
- Add `GetCoupleExpensesUseCase` returning the union of both partners' live expenses, each marked `mine` /
  `theirs` from the reader's perspective, ordered most-recent-first.
- Keep the derivation (perspective) in the domain via a `CoupleExpenseVirtualObject`, not in a mapper.
- Read partner expenses **without coupling `pairing` to `expenses`** — via a port pairing owns.
- Guard the view behind a live pair (`NotPairedError`, pt-BR, non-leaking).
- Ship a runnable vertical slice: reuse the in-memory `PairRepository`; a fake `PartnerExpenseReader` for
  tests; no production cross-context adapter yet.

**Non-Goals:**
- **couple-budget** (the combined `[min(starts), max(ends)]` panorama) and **dissolve-pair**.
- The real expenses-backed `PartnerExpenseReader` adapter, its composition-root wiring, and the matching
  `list`-all method on the `expenses` repository (no app bootstrap / ORM exists yet).
- Any date-range slicing, pagination, write through the view, web handler, or ORM model/mapper.

## Decisions

**1. `Perspective` — an enum (its own domain shape), the reader-relative ownership.**
`features/pairing/domain/enums/perspective.py` → `class Perspective(Enum)` with `MINE = "mine"` and
`THEIRS = "theirs"`. It lives in `domain/enums/` (alongside `PersonStatus`), not `value_objects/`: a closed
domain set validates nothing and carries no behavior, so it is not a value object — it is its own domain
shape (see the enums convention in CLAUDE.md). It is the literal encoding of the product's central idea —
*a couple is a point of view*. Alternative considered: a plain `bool mine` on the read-model — rejected as
less intention-revealing and because the perspective is a first-class domain concept worth naming.

**2. `CoupleExpenseVirtualObject` — composes one partner expense + reader, derives the perspective.**
`features/pairing/domain/virtual_objects/couple_expense_virtual_object.py`. A frozen dataclass holding the
expense's `expense_id`, `owner_id`, `amount: MoneyValueObject`, `occurred_on: date`, `created_at:
datetime`, `description: str | None`, plus `reader_id: str`. It exposes a derived
`perspective -> Perspective` (`MINE` when `owner_id == reader_id`, else `THEIRS`). This is the same shape as
`ActiveBudgetVirtualObject`: neither entity (no identity) nor value object (it composes + derives), never
stored. Holding `amount` as a `MoneyValueObject` keeps money exact-decimal across the context boundary
rather than letting a raw `Decimal` leak through the domain. The derivation lives here (the domain), not in
the mapper — matching *"keep money/derivation math in the domain"*.

**3. Reading partner expenses via a consumer-owned gateway port — never a cross-module import.**
`pairing` defines `PartnerExpenseReaderInterface` in `features/pairing/application/interfaces/` —
`async def list_for_person(person_id: str) -> list[PartnerExpenseData]`, returning the person's **live**
expenses (the adapter owns the soft-delete filter). This is pairing's anti-corruption seam over "a
person's expenses": pairing speaks its own vocabulary and depends only on this ABC. It is a **gateway**,
not a repository — it reads data pairing does not own and maps no entity to a table — exactly like
budgeting's `SpendReaderInterface`. The concrete adapter that reads the expenses ledger is wired at the
**composition root** (the only layer permitted to know both modules) and is **deferred** alongside the
absent app bootstrap; the matching `list`-all method on the `expenses` repository lands with that wiring,
not here. A hand-written `FakePartnerExpenseReader` satisfies the port in tests.

Alternative considered: have the port return `expenses`' own `ExpenseEntity` — rejected, it would force a
`pairing → expenses` domain import, the exact coupling the modular monolith forbids. Returning pairing's
own `PartnerExpenseData` keeps the dependency pointing only at pairing's abstraction.

**4. `PartnerExpenseData` — the cross-context read shape, in pairing's vocabulary.**
`features/pairing/application/data/partner_expense_data.py`: a frozen dataclass (`id`, `person_id`,
`amount: Decimal`, `occurred_on: date`, `created_at: datetime`, `description: str | None`) — the shape the
gateway returns. It is an application `data` read-model (the layer a gateway returns into), not a domain
type, so it carries no behavior and needs no value-object justification. The use case unpacks its fields
into the `CoupleExpenseVirtualObject` constructor (wrapping `amount` in `MoneyValueObject`); the virtual
object never imports this application type, so the dependency rule holds.

**5. The use case: guard for the pair, then union and mark.**
`GetCoupleExpensesUseCase(pair_repository, partner_expense_reader)`.
  1. `pair = await pair_repository.find_active_by_person(reader_id)`; if `None` → `NotPairedError`.
  2. `partner_id` = the *other* id of the pair (`person_b_id` if `reader_id == person_a_id`, else
     `person_a_id`).
  3. The two reads are independent → `asyncio.gather(partner_expense_reader.list_for_person(reader_id),
     partner_expense_reader.list_for_person(partner_id))`.
  4. Build a `CoupleExpenseVirtualObject` per expense (passing `reader_id`), concatenating both lists.
  5. Sort most-recent-first: `occurred_on` desc, then `created_at` desc.
  6. Map each via `CoupleExpenseDataMapper.to_data` → return `list[CoupleExpenseData]`.

The guard (step 1) precedes the gathered reads, per the async rule that a short-circuiting check comes
before any independent work. Sorting in the use case (application) is orchestration, not a domain rule, so
it does not belong in the virtual object.

**6. `NotPairedError` — pt-BR, non-leaking, its own file.**
`features/pairing/domain/errors/not_paired_error.py` → message `"Você não está em um par ativo."`. It
states only the reader's own condition and leaks no partner data. One class per file, per convention.

**7. `CoupleExpenseData` + `CoupleExpenseDataMapper` — the public read-model.**
`features/pairing/application/data/couple_expense_data.py`: a frozen dataclass (`id`, `person_id`,
`amount: Decimal`, `occurred_on: date`, `created_at: datetime`, `description: str | None`, `perspective:
str`). `perspective` is unwrapped to its plain string value (`"mine"` / `"theirs"`), mirroring how
`ActiveBudgetDataMapper` unwraps money to a `Decimal`. `CoupleExpenseDataMapper.to_data(virtual_object)`
is the dedicated `@staticmethod` mapper, one per file.

**8. No new production adapter, no model/mapper.**
The in-memory `PairRepository` is reused unchanged. The only new "adapter" is the test
`FakePartnerExpenseReader`. No `Model` / `ModelMapper` until an ORM is chosen.

## Risks / Trade-offs

- **Deferred real `PartnerExpenseReader` adapter.** → The view is fully specified and exercised via a fake;
  the production adapter (reading the expenses ledger) and its composition-root wiring land with the app
  bootstrap. The port and contract exist now, so wiring later touches no domain or use-case code. The
  `expenses` repository will need a `list`-all-for-person method then; tracked, not built here.
- **Whole-ledger union, no date range or pagination.** → Acceptable: a couple is little data (per the
  project's no-cache decision). If volume ever warrants it, a ranged/paged variant is an additive change
  behind the same port.
- **Read-consistency across two ledgers is non-transactional.** → The two `list_for_person` reads are not a
  snapshot; an expense added between them could appear or not. Harmless for a read-only view with no
  invariant spanning the two ledgers; revisit only if a consistent snapshot is ever required.
- **`perspective` derived per reader, never stored.** → The same expense is `mine` for its owner and
  `theirs` for the partner; correct by construction since it is recomputed at read-time from `reader_id` —
  no stored flag to go stale, consistent with derive-don't-store.
