## Context

`identity` already ships `register-person` (`sign_up`) and `delete-account`. Both presuppose an authenticated
person — `delete-account` even re-confirms "a live session **and** the password" — yet no use case turns a
credential into an authenticated identity. The two halves needed already exist:
`PersonRepositoryInterface.find_active_by_email(EmailValueObject) -> PersonEntity | None` (already excludes
inactive persons) and `PasswordHasherInterface.verify(password, hash) -> bool` (already used by
`delete-account`, returns `False` on mismatch rather than raising). The `PersonData` read-model and its
mapper exist too. So `sign_in` is a thin orchestration with one new domain rule (anti-enumeration) and one
security nuance (timing). The build stage is transitional: pure domain + application ports + the in-memory
adapter; no ORM `Model`/`ModelMapper`.

## Goals / Non-Goals

**Goals:**
- Verify `email + password` against the active person's hash and return `PersonData` on success.
- Make every failure indistinguishable: one generic `InvalidCredentialsError`, and uniform response timing
  whether or not the email exists.
- Reuse existing ports — no new contract.

**Non-Goals:**
- No `Session` entity, no token/JWT issuance, no `sign_out`. Those are the web edge, deferred behind the
  existing ports until the transport is chosen.
- No change to `register-person`'s or `delete-account`'s requirements. No ORM persistence.

## Decisions

**1. Return `PersonData`, not a `Session`.** The use case answers "this credential belongs to this active
person" and stops. Issuing a session/token is a transport decision (JWT vs server-side) explicitly parked.
_Alternative — model `Session` now:_ rejected as inventing an entity before its lifecycle is decided, against
"a value/entity must earn its existence."

**2. A distinct `InvalidCredentialsError`, never reuse `IncorrectPasswordError`.** `delete-account`'s error is
post-auth and may be specific ("your password is wrong"); `sign_in` is pre-auth and must be generic over
*both* the email and the password. Message: pt-BR `"E-mail ou senha inválidos."`, naming neither half.
_Alternative — reuse `IncorrectPasswordError`:_ rejected; its message and intent are about a known person’s
password, which would leak that the email exists.

**3. Anti-enumeration collapses validation too.** Building `EmailValueObject` from input can raise
`InvalidEmailError`. In `sign_in` that must NOT surface — a malformed email has to look exactly like a wrong
credential. The use case therefore catches the value-object validation failure and re-raises
`InvalidCredentialsError`. Normalization (lowercase/trim) from `EmailValueObject` is still used for the
lookup when the email *is* well-formed.

**4. Timing equalization via a constant decoy hash.** If the not-found path skipped `verify`, it would return
faster than the wrong-password path and leak email existence. So the use case ALWAYS calls `verify` exactly
once: against the found person's hash, or — when none is found — against a constant, valid Argon2 decoy hash,
discarding the result. This deliberately inverts the usual "cheap guard before expensive call" ordering (here
we pay the hash on purpose). The decoy is a module-level constant `str` in the use case's file (a real Argon2
digest of an arbitrary throwaway secret) — a hash is a plain `str`, so it earns no value object and needs no
new port; `verify` already takes `(PasswordValueObject, str)`. _Alternative — inject the decoy via a port:_
rejected as ceremony; it is a constant, not a swappable collaborator.

**5. Sequential awaits, no `gather`.** There is a real data dependency: find the person, *then* verify against
*that* person's hash. The two calls cannot overlap, so `asyncio.gather` does not apply.

**6. `PasswordValueObject` for the input password.** The raw password is wrapped in `PasswordValueObject`
before `verify`, consistent with the hasher port contract (it takes a `PasswordValueObject`, never a raw
`str`). Note `PasswordValueObject` enforces the strength policy; an input that fails it cannot match any
stored hash anyway, so a policy failure must also collapse into `InvalidCredentialsError` (same anti-leak
rule as the email) rather than surfacing `WeakPasswordError`.

## Risks / Trade-offs

- **[The decoy hash drifts from the real Argon2 parameters over time]** → It only needs to be a valid digest
  that `verify` can parse and reject; its cost approximating the real one is enough to equalize timing. If
  Argon2 parameters change materially later, regenerate the constant. Documented inline where it is defined.
- **[Timing equalization is approximate, not constant-time]** → Argon2 verify time varies slightly; we
  equalize the dominant cost (running a full verify on every path), which removes the gross skip-vs-verify
  signal. Perfect constant-time is out of scope and not required by the spec.
- **[Catching `InvalidEmailError`/`WeakPasswordError` could mask genuine bugs]** → The catch is scoped
  narrowly to the value-object construction step and only those validation errors, re-raised as
  `InvalidCredentialsError`; unrelated exceptions propagate.
- **[A future `sign_out`/session need]** → Parked deliberately; returning `PersonData` keeps the seam clean so
  the web edge can wrap it in whatever session transport is later chosen, with no domain change.
