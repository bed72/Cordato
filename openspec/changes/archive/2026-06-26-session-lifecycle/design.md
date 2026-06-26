## Context

`sign_in` proves a credential and returns `PersonData`, but mints nothing the caller can present later — so
there is no per-request auth and no `sign_out`. The product's front-end is a **Flutter mobile app** (no web
app for the product), so the session is an **opaque bearer token** kept in the device secure storage and sent
in `Authorization`. A storage-backed server-side session is chosen over a stateless JWT for **revocation**
(lost device / explicit sign-out invalidate instantly) and because it fits the current in-memory transitional
stage with real domain substance. It is also **client-agnostic** — a fact that is now concrete: Google Play
mandates a web account-deletion path reachable without the app, so a minimal web edge is coming, and the same
`Session` will authenticate that web flow with no redesign. The build stage is unchanged: pure domain +
application ports + in-memory adapters + a real CSPRNG gateway; no ORM `Model`/`ModelMapper`.

## Goals / Non-Goals

**Goals:**
- A `SessionEntity` issued at sign-in, validated by token on each request, and revoked at sign-out.
- Anti-enumeration parity with sign-in: validate and sign-out are generic and non-leaking.
- Reuse the existing determinism ports (uuid7 id, clock) and identity ports; add only the two genuinely-new
  ports (session repository, token generator).

**Non-Goals:**
- No JWT, no cookies, no web framework, no "sign out all devices", no ORM persistence. The web
  account-deletion endpoint is a later change (it will ride this same `Session`).

## Decisions

**1. Opaque server-side session token, not JWT.** Possession of an unguessable token is the authorization;
the server holds the truth and can revoke. _Alternative — JWT:_ rejected; statelessness forfeits instant
revocation, which a mobile + account-deletion context actively wants, and buys nothing without a web SPA.

**2. `token` is a separate CSPRNG secret, distinct from `id`.** `id` stays the opaque uuid7 anchor (good
index locality, but time-ordered and therefore guessable); the bearer secret MUST be unpredictable, so it is
a separate `secrets.token_urlsafe` value — exactly the `InviteCode.code` pattern. Lookups are by `token`;
the domain never derives one from the other. _Alternative — reuse the id as the token:_ rejected; a
time-ordered id is a weak bearer secret.

**3. `revoked_at` + `expires_at`, validity computed, never stored as a flag.** A session is live ⇔
`revoked_at is null` AND `expires_at > now`. Sign-out sets `revoked_at`; expiry is pure time math against the
`ClockInterface`. `revoked_at` is named for intent (not the generic `deleted_at`) because revocation is the
domain event here. _Alternative — a stored `is_valid` boolean:_ rejected; it is derivable and would go stale
(derive-don't-store).

**4. The repository owns the validity filter.** `find_valid_by_token(token, now)` returns only a live session,
mirroring how active/soft-delete reads are the repository's responsibility — the use cases never re-filter
revoked/expired rows. `now` is passed in (from the clock) rather than read inside the adapter, keeping the
adapter deterministic under test. _Alternative — return any session and filter in the use case:_ rejected;
leaks the soft-delete/expiry concern upward.

**5. `validate-session` is the keystone that makes sign-out observable.** Without a token consumer, issuing a
token is half a feature and a revocation has no visible effect. `validate-session` (token → `PersonData`) is
also precisely what the app calls on every authenticated request and what the future web edge will call. It
re-checks the person is still active, so a deleted account's outstanding tokens stop working.

**6. One generic `InvalidSessionError` (pt-BR `"Sessão inválida."`) for validate; sign-out has no error.**
Validate collapses unknown / expired / revoked / inactive-person into one non-leaking error — same
anti-enumeration discipline as sign-in. Sign-out is an **idempotent no-op** on any non-live token: it must
never be an oracle for whether a token exists or in what state, so it raises nothing and simply does nothing
when there is nothing live to revoke.

**7. Time-to-live as a named constant; `expires_at = created_at + SESSION_TIME_TO_LIVE`.** Mobile sessions
are long-lived; default `SESSION_TIME_TO_LIVE = timedelta(days=30)` (a single source-of-truth constant,
adjustable, spelled out — never "TTL", per the no-abbreviation rule), derived once at issuance by the entity's
`create(...)` factory. _Alternative — a sliding/renewing expiry:_ deferred; a fixed time-to-live is the
simplest correct start.

**8. `SessionData` read-model fed by an `AuthenticatedSessionVirtualObject` (one-arg mapper).** `SessionData
{ token: str, expires_at: datetime, person: PersonData }` needs data from **two** entities (the session and
its person), but a mapper must take exactly **one cohesive input** — never two loose params. So sign-in
composes an `AuthenticatedSessionVirtualObject` (domain/virtual_objects) that holds the `SessionEntity` + the
`PersonEntity` and exposes `token` / `expires_at` / `person`; `SessionDataMapper.to_data(authenticated_session)`
takes that single object and composes the existing `PersonDataMapper`. This mirrors the couple views
(`CoupleExpenseVirtualObject` → one-arg mapper). It is a Virtual Object, not an entity/VO: it references
entities (its job), has no identity/lifecycle, is never stored. `validate-session` returns plain `PersonData`
(reuse its mapper). Sign-in's return type changes `PersonData → SessionData` — a deliberate breaking change to
that read-model, captured as the `sign-in` MODIFIED delta.

**9. Async + ordering.** Sign-in keeps its guard-before-expensive ordering and timing equalization; only past
a successful verify does it issue the session, gathering the independent `id` / `created_at` / `token`
generations (no data dependency) via `asyncio.gather`, then computing `expires_at` from `created_at`.

## Risks / Trade-offs

- **[Plaintext tokens at rest in the in-memory store]** → Acceptable at the transitional stage; when the ORM
  lands, store only a hash of the token and look up by hash (the port signature `find_valid_by_token` already
  hides this — the adapter changes, the domain does not). Noted for the persistence change.
- **[No "sign out all devices" / no revoke-on-password-change yet]** → Out of scope; the per-session model
  makes adding a "revoke all for person" method later a pure repository addition, no redesign.
- **[Fixed time-to-live with no refresh]** → A session simply expires at 30 days and the user signs in again; sliding
  expiry / refresh tokens are a later refinement behind the same ports.
- **[Clock skew on expiry]** → Single authoritative `ClockInterface.now()` is passed into the validity check,
  so issuance and validation share one clock; no cross-source skew.
