## Context

Identity already has the full account boundary except in-place self-editing: `sign-up` (create),
`sign-in` / `validate-session` / `sign-out` (session lifecycle), and `delete-account` (the nuclear,
irreversible exit). The only way to fix a typo'd name or move an email today is delete-and-resignup,
which discards the person's `id`, `created_at`, and ledger. This change adds the missing
maintenance arm: an authenticated person edits their own `name` and `email` in place.

It mirrors `edit-budget` (an in-place edit under per-person authorization that re-validates the
relevant invariants) and reuses `sign-up`'s email/name validation and uniqueness machinery verbatim.
The slice is still ORM-deferred: pure `domain/` + `application/` ports + the in-memory `PersonRepository`.

## Goals / Non-Goals

**Goals:**
- An authenticated person updates their own `name` and `email` in place, preserving `id`,
  `created_at`, `status`, and password hash.
- Re-validate email (well-formed + normalized) and name (non-empty after trim).
- Re-enforce the email-uniqueness invariant against the *other* active people, excluding the acting
  person so re-saving one's own email is allowed.
- Per-person authorization: the acting identity is the `requester_id` resolved upstream from a live
  session; an unresolved requester rejects with `InvalidSessionError`.

**Non-Goals:**
- **Changing the password** — that is its own change (`change-password`), with its own re-confirmation
  semantics and likely session invalidation.
- **Partial / patch updates** — both editable fields are always supplied (full replacement), matching
  `edit-budget`. A field the caller does not want to change is re-submitted with its current value.
- **Edit auditing** — no `updated_at` field; adding one is a separate change.
- **Re-confirming the password to edit** — an account edit is reversible, unlike `delete-account`; the
  live session resolved upstream is sufficient authorization.

## Decisions

### Authorization: `requester_id` on the command, resolved via `find_active_by_id`
The command carries `requester_id` (resolved upstream by `validate-session`), exactly like
`edit-budget`'s `requester_id`. The use case re-resolves it through
`PersonRepositoryInterface.find_active_by_id`; `None` → `InvalidSessionError`.
- *Why `InvalidSessionError` and not a new "person not found" error?* The acting person is the
  authenticated subject, not a looked-up resource. If their id no longer resolves to an active
  account, the session is no longer valid — the same condition `validate-session` already collapses
  to `InvalidSessionError`. Introducing a new error would split one concept in two.
- *Alternative considered — pass the resolved `PersonEntity` in:* rejected; the use case must re-read
  the live person to mutate and persist it anyway, and keeping ports speaking ids keeps the command a
  flat data shape consistent with the other slices.

### New port method `update(person)`, distinct from `create` / `delete`
`PersonRepositoryInterface` gains `async def update(self, person: PersonEntity) -> None` to persist a
mutated *active* person. This parallels `edit-budget` adding `update` next to `create`/`delete`, and
keeps the three persistence intents explicit (introduce / mutate-live / retire) rather than overloading
`create` as an upsert.

### Mutation lives in the entity: `PersonEntity.update_account(*, name, email)`
A new entity method overwrites `name` and `email` in place and leaves `id`/`created_at`/`status`/
`password` untouched — the same shape as `PersonEntity.create`/`delete` owning their own transitions.
Validation lives in the value objects (`EmailValueObject`, `NameValueObject`), constructed in the use
case before the mutation, so the entity receives already-valid VOs.

### Email-uniqueness with self-exclusion
The use case reads `find_active_by_email(email)`; if it returns a person whose `id` differs from the
acting person's, raise `EmailAlreadyInUseError`. A match on the acting person themselves is *not* a
collision (re-saving your own email is allowed) — the same self-exclusion idea as `edit-budget`
excluding a budget from its own overlap check.

### Independent reads are gathered
`find_active_by_id(requester_id)` and `find_active_by_email(email)` consume no result of each other, so
they are issued together with `asyncio.gather`, honoring the async-maybe-I/O contract. The cheap VO
construction (a pure guard) runs *before* the gather, so a malformed email/name is rejected without any
repository call.

## Risks / Trade-offs

- **Self-exclusion done by `id` comparison, not by oracle.** → The check compares the found holder's
  `id` to the acting person's `id`; identity equality on `PersonEntity` is by `id`, so this is exact
  and cannot be fooled by field changes.
- **No transaction at the in-memory stage** (read-then-write is not atomic). → Acceptable and
  consistent with every other slice; the indivisible boundary arrives with the ORM behind these same
  ports. The only pre-mutation failures (validation, unresolved requester, duplicate email) happen
  before any write, leaving state intact.
- **Full-replacement semantics could surprise a caller expecting PATCH.** → Documented as a Non-Goal
  and matched to `edit-budget`; the web layer (later) can offer a partial-update façade that fills
  unchanged fields from the current `PersonData` before calling the use case.
