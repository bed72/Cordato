## Context

The individual core is complete (register-person, record-expense, create-budget, active-budget). The
defining capability of Trocado — the shared couple view — begins with pairing, and pairing begins with an
invite. This change builds the first, smallest slice of the new `pairing` context: minting an
`InviteCode`. It follows the established pattern of every prior slice: pure `domain/`, async ports in
`application/`, and working in-memory / gateway adapters in `infrastructure/`, fully testable without a
web framework or ORM. The determinism ports (`ClockInterface`, `IdentifierProviderInterface`) and their
adapters already exist in `core/` and are reused as-is.

## Goals / Non-Goals

**Goals:**
- Introduce the `pairing` context with the `InviteCodeEntity` and a `CreateInviteCodeUseCase`.
- Generate the token from a CSPRNG behind a new async port, so the cryptographic source is an injectable
  adapter and the use case stays pure and deterministic under test.
- Fix the ~1-day TTL as a domain rule inside the entity factory, derived from `created_at`.
- Ship a runnable vertical slice: in-memory repository + real `secrets`-backed token generator.

**Non-Goals:**
- **accept-invite** (validating + consuming a code, creating the `PairEntity`, the ≤1-active-pair
  invariant, expiry/self-invite/already-paired checks). That is the next slice and owns those rules.
- Listing/looking-up/revoking codes; capping active codes per person.
- Authorizing `creator_id` against an existing/active person (arrives with auth).
- Any web handler or ORM model/mapper (no framework/ORM chosen yet).

## Decisions

**1. New `pairing` context, mirroring the canonical layering.**
`src/trocado/features/pairing/{domain,application,infrastructure}`. Same shape as `expenses`/`budgeting`,
so nothing new architecturally — only a new bounded context.

**2. `code` is a plain `str`, not a value object.**
The token is opaque: no invariant to enforce, no normalization, no behavior. Per *"a value object must
earn its existence — no primitive-wrapping"*, wrapping it would be ceremony. (Contrast `MoneyValueObject`
/ `EmailValueObject`, which validate and normalize.) The token's *generation* is the interesting part, and
that lives behind a port — not in a wrapper type.

**3. A new async `TokenGeneratorInterface` port + `TokenGenerator` gateway, local to `pairing`.**
- Port: `features/pairing/application/interfaces/token_generator_interface.py` — `async def generate()
  -> str`. Async **by contract**, exactly like the determinism ports: it does no I/O today (`secrets` is
  in-process), but declaring it async honors the async-maybe-I/O contract so a future external token
  service slots in with zero ripple. The use case can then `asyncio.gather` it alongside `id`/`now`.
- Adapter: `features/pairing/infrastructure/gateways/token_generator.py` (`TokenGenerator`), backed by
  `secrets.token_urlsafe(...)` for a short, URL-safe, unpredictable token. The sync `secrets` call is
  wrapped off-loop (`asyncio.to_thread`) at the adapter edge, never leaked inward — same discipline as the
  Argon2 hasher in identity.
- It lives in `pairing`, not `core/`, because only pairing needs it now. It can be promoted to the kernel
  the day a second context needs token generation — not preemptively. Per the *"never the lib's name"*
  rule the class is `TokenGenerator`, never `SecretsTokenGenerator`.

**4. The ~1-day TTL is fixed in the entity factory, from `created_at`.**
`InviteCodeEntity.create(...)` is the only sanctioned constructor. It receives `id`, `created_at`,
`creator_id`, and `code`, and computes `expires_at = created_at + timedelta(days=1)` and sets
`consumed_at = None`. The caller cannot influence the TTL (spec requirement). Keeping the duration in the
domain (not the use case) makes it a stated rule, testable with a fixed clock. The exact span is one day
via `datetime.timedelta`; if the product later wants a different window it is a one-line domain change with
its own spec.

**5. Entity equality by identity.**
Like the other entities, `InviteCodeEntity` is equal by `id` (`__eq__`/`__hash__` on `id`), never by
field values.

**6. The use case orchestrates ports, gathering the independent ones.**
`CreateInviteCodeUseCase(repository, token_generator, clock, identifier)`. The three reads — `id`,
`created_at`, `token` — are mutually independent, so they are issued together with `asyncio.gather`. There
is no short-circuiting guard to place before them (no validation in this slice), so the gather is
unconditional. It then builds the entity via the factory, persists it through the repository, and returns
`InviteCodeData` via `InviteCodeDataMapper`.

**7. Data shapes named by nature.**
`CreateInviteCodeData` (command — carries only `creator_id`), `InviteCodeData` (read-model — `id`, `code`,
`creator_id`, `expires_at`, `consumed_at`, `created_at`), `InviteCodeDataMapper.to_data(entity)`. No
`in`/`out` naming; web request/response shapes are deferred with the framework.

**8. In-memory repository now; no model/mapper yet.**
`InviteCodeRepositoryInterface` (port, `application/interfaces`) with `async def create(invite_code) ->
None`. The in-memory `InviteCodeRepository` stores entities directly — no `InviteCodeModel` /
`InviteCodeModelMapper` until an ORM is chosen (deferred, not skipped). Soft-delete machinery is not
introduced here: an invite code has no `deleted_at` in the domain model, and there is no read/audit method
in this slice.

## Risks / Trade-offs

- **No uniqueness guarantee on the token** → `secrets.token_urlsafe` with sufficient entropy makes
  collisions astronomically unlikely; a DB unique constraint will reinforce it when the ORM lands. The
  in-memory adapter does not enforce uniqueness, matching the deferred-persistence stage.
- **No cap on active codes per creator** → a person could mint many codes. Out of scope by decision;
  redemption is single-use and expiring, so the blast radius is bounded. A cap, if wanted, is its own
  spec.
- **`creator_id` is unauthenticated** → consistent with every prior slice; the authorization check lands
  with auth. Stored as given for now.
- **TTL hard-coded in the domain** → intentional: it is a domain rule, not configuration. Changing it is a
  spec-bearing domain edit, which is the desired friction.
