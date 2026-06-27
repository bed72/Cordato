## Context

Identity's account-mutation surface grew asymmetric. `update-password` already treats the password as a
credential: it re-confirms the *current* password (no oracle) before the swap and purges every *other*
session while keeping the acting one. But `update-account` edits `name` **and** `email` together as plain
profile fields — no re-confirmation, no session purge — even though the **email is the login identifier**.
The result: reassigning who can sign in costs *less* than rotating the password.

This change makes the surface symmetric and self-describing by splitting `update-account` into three sibling
capabilities named after exactly what each mutates:

- **`update-name`** — a plain profile edit (the name-only remainder of `update-account`).
- **`update-email`** — credential-sensitive, the close cousin of `update-password`: re-confirm the current
  password, swap the email, purge other sessions.
- **`update-password`** — unchanged, already in place.

`update-email` reuses `update-password`'s machinery almost verbatim — the hasher guard and
`purge_for_person_except` — differing only in the mutated field (email vs. hash) and in adding a uniqueness
re-check (which `update-account` already had). The slice stays ORM-deferred: pure `domain/` + `application/`
ports + the in-memory `PersonRepository` and `SessionRepository`.

## Goals / Non-Goals

**Goals:**
- An authenticated person changes their own email, preserving `id`, `created_at`, `status`, `name`, and the
  password hash — the only account mutation is the email.
- Re-confirm identity with the current password (`hasher.verify`); a wrong password and an unresolved
  requester fail identically (`IncorrectPasswordError`, no oracle).
- Re-validate and normalize the new email (`EmailValueObject` → `InvalidEmailError`), cheaply and before the
  verify.
- Re-enforce email uniqueness among *other* active people (`EmailAlreadyInUseError`, echoing no address);
  re-saving the person's own email is allowed.
- Purge every *other* session and keep the acting one, dropping any pre-change token.
- Carve `update-name` out of `update-account` as a name-only profile edit, and remove `update-account`.
- Expose no secret; return the person's public data (`PersonData`).

**Non-Goals:**
- **Email *verification* (confirm-before-switch via a one-time link).** That needs an email-delivery gateway,
  which is deferred (sign-up itself is born `active` without verification). `update-email` switches directly,
  behind the same future gateway. Deferred, not skipped.
- **A "forgot password / recover by email" flow** — unauthenticated recovery, a separate capability with its
  own delivery gateway.
- **Editing name and email in one request** — intentionally dropped; an email change must cost a password
  re-confirmation. A caller that wants both makes two calls.
- **Purging the acting session (forced re-login)** — the device that made the change stays signed in, exactly
  as `update-password` decided.
- **Edit auditing** — no `email_changed_at` field; consistent with `update-password`/`update-account`.

## Decisions

### Three siblings named after what they mutate; `update-account` is removed
`update-account` becomes `update-name` (name only) + `update-email` (email, credential-sensitive). The
combined edit is removed (**BREAKING**). This follows the project's own precedent of renaming for naming
consistency (`change-password` → `update-password`) and yields a surface where the name says the blast radius:
`update-name` is cheap, `update-email`/`update-password` cost a password re-confirmation because they touch
what authenticates the account.

### `update-email` re-confirms with the current password, exactly like `update-password`
The guard is `person = find_active_by_id(requester_id)` then `hasher.verify(current_password,
person.password)`; `person is None or not verified` → `IncorrectPasswordError`. The two failure causes (no
active person / wrong password) collapse to one error so nothing leaks which occurred — the same no-oracle
shape `update-password` and `delete-account` use. This is the crux of the change: the email is the login
identifier, so reassigning it is a credential-sensitive act and earns the same guard as the password.

### `update-name` keeps `update-account`'s lighter guard (no password)
A name is not a credential, so `update-name` does **not** re-confirm the password. It keeps
`update-account`'s rule: resolve the active requester, and an unresolved one → `InvalidSessionError`. (The
two capabilities deliberately fail differently on an unresolved requester — `InvalidSessionError` for the
unguarded name edit, `IncorrectPasswordError` for the password-guarded email edit — because only the latter
must avoid an oracle.)

### The command shapes mirror their cousins
- `UpdateNameData(requester_id: str, name: str)` — the raw name; the `NameValueObject` is built in the use
  case (as `update-account` did).
- `UpdateEmailData(requester_id: str, current_session_token: str, current_password: PasswordValueObject,
  new_email: str)` — mirrors `UpdatePasswordData`: the acting id, the acting session's token (the one kept
  alive), and the current password as a policy-checked `PasswordValueObject` built at the data boundary. The
  `new_email` stays a raw `str`; its `EmailValueObject` is built in the use case, exactly as `update-account`
  and `sign-up` build email VOs from raw input.

### Ordering in `update-email`: cheap email VO → reads (gathered) → identity guard → uniqueness → swap → persist + purge
1. `EmailValueObject(new_email)` — pure, cheap; a malformed email is rejected (`InvalidEmailError`) before
   any I/O or hashing.
2. `person, holder = await asyncio.gather(find_active_by_id(requester_id), find_active_by_email(email))` —
   two independent reads, issued together (the same gather `update-account` uses).
3. Identity guard: `if person is None or not await hasher.verify(current_password, person.password): raise
   IncorrectPasswordError`. `verify` is the expensive call and runs *after* the cheap reads; it gates
   everything below (a real data dependency), so it is awaited sequentially, never gathered.
4. Uniqueness: `if holder is not None and holder.id != person.id: raise EmailAlreadyInUseError` — the acting
   person is excluded, so re-saving one's own email is allowed. The holder read happened in step 2, but its
   *verdict* is only consulted past the identity guard, so a wrong password never reveals a uniqueness result.
5. `person.update_email(email)`; then `await asyncio.gather(person_repository.update(person),
   session_repository.purge_for_person_except(person.id, current_session_token))` — the two **I/O** effects
   are independent, so they are gathered, exactly as `update-password` gathers its persist + purge.

### Mutations live in the entity: two narrow transitions replace `update_account`
`PersonEntity.update_account(name, email)` is removed; in its place:
- `update_name(self, name: NameValueObject) -> None` — overwrite `name` only.
- `update_email(self, email: EmailValueObject) -> None` — overwrite `email` only.

Each leaves `id`/`created_at`/`status`/password and the *other* editable field untouched, joining the
sanctioned transitions `create` (birth), `update_password` (rotate), and `delete` (retire). Splitting the
transition keeps each use case's effect honest: `update-name` literally cannot touch the email, and vice
versa.

### `update-email` returns `PersonData`; `update-password` returns `None`
`update-email` inherits `update-account`'s return: the public `PersonData` via `PersonDataMapper` — it leaks
no secret (no password/hash) and the new email is already known to the caller, so surfacing the resulting
public record is convenient and safe. This differs from `update-password`, which returns `None` only because
there is genuinely nothing non-secret to return. The added session purge is a security effect, not a reason
to withhold the public data.

### No new ports, errors, models, or dependencies
Everything is reused: `PersonRepositoryInterface` (`find_active_by_id`, `find_active_by_email`, `update`),
`PasswordHasherInterface.verify`, `SessionRepositoryInterface.purge_for_person_except` (added by
`update-password`), `PersonDataMapper`, and the errors `InvalidEmailError`, `EmailAlreadyInUseError`,
`IncorrectPasswordError`, `InvalidNameError`, `InvalidSessionError`. Still no `Model`/`ModelMapper` (ORM
deferred).

## Risks / Trade-offs

- **BREAKING — the combined name+email edit is gone.** A client that updated both at once now makes two calls,
  and the email call costs a password. → Intended: the asymmetry it removes (cheap login-identifier swap) is
  exactly the risk worth the breakage. There is no production web client yet (web layer deferred), so the
  blast radius is internal callers and tests, all updated in this change.
- **No transaction at the in-memory stage**: the email swap and the session purge are not atomic. →
  Acceptable and consistent with `update-password`/`delete-account`; the guard (the only pre-effect failure)
  runs strictly first, so a rejected request changes nothing, and the indivisible boundary arrives with the
  ORM behind these same ports. A crash between the two effects leaves the new email set but stale sessions
  un-purged — fail-safe-ish; a retry re-purges idempotently.
- **Keeping the acting session means a thief currently on it survives the change.** → Same threat model and
  decision as `update-password`: the initiator is the legitimate holder of the acting session by assumption;
  forced full re-login remains a future toggle.
- **Re-saving one's own email still triggers a session purge.** → Consistent and harmless: the operation is
  "change email", the uniqueness rule explicitly allows the self-match, and the purge is idempotent. Treating
  it as a security-bearing operation (rather than special-casing a no-op) keeps the rule simple.
- **No email verification before the switch.** → The login identifier changes to an address that was never
  proven reachable; a typo could lock the person out at next sign-in. Accepted for now (no email gateway,
  same posture as sign-up being born `active`); verification slots in behind the deferred gateway as its own
  change.
