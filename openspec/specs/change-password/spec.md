# change-password Specification

## Purpose
TBD - created by archiving change change-password. Update Purpose after archive.
## Requirements
### Requirement: An authenticated person changes their own password in place

The system SHALL let an authenticated person change their own password — replacing the stored password
hash — while preserving the person's `id`, `created_at`, `status`, `name`, and `email`. The only mutation
is the credential: the new password is hashed and the prior hash is overwritten, and no new person is
created. On success the system SHALL expose no secret of any kind: it SHALL return no plaintext and no
hash, neither the old nor the new.

#### Scenario: Person changes their own password

- **WHEN** an authenticated person submits the correct current password and a new password that satisfies
  the policy
- **THEN** the system replaces that person's password hash with the hash of the new password, keeps their
  id, created_at, status, name, and email, and exposes no plaintext or hash

#### Scenario: The new hash actually authenticates afterward

- **WHEN** a person has changed their password
- **THEN** signing in with the new password succeeds and signing in with the old password fails

### Requirement: Identity is re-confirmed by the current password, with no oracle

The system SHALL resolve the acting person as the active account identified by the `requester_id` carried
on the command (itself resolved upstream from a live session), and SHALL re-confirm identity by verifying
the submitted **current** password against that person's stored hash, before any change is made. A
`requester_id` that resolves to no active person and an incorrect current password SHALL fail
**identically** with an "incorrect password" error that reveals nothing about which case occurred, and
nothing SHALL be changed. A person SHALL only ever change their own password; there is no path to change
another person's.

#### Scenario: Wrong current password is rejected

- **WHEN** the submitted current password does not match the acting person's stored hash
- **THEN** the system rejects the change with an "incorrect password" error and changes nothing

#### Scenario: Unresolved acting person is rejected identically

- **WHEN** the command's requester_id matches no active person
- **THEN** the system rejects the change with the same "incorrect password" error — indistinguishable from
  a wrong password — and changes nothing

### Requirement: The new password is re-validated against the policy

The system SHALL validate that the submitted new password satisfies the password policy (at least the
minimum length) and SHALL reject a non-conforming password with a "weak password" error, changing nothing.
This validation SHALL be evaluated before the current-password verification or any hashing, so a malformed
new password is rejected cheaply. The rejection MAY state the minimum length (a non-sensitive fact) but
SHALL NOT echo the submitted value.

#### Scenario: Too-short new password is rejected

- **WHEN** the submitted new password is shorter than the policy minimum
- **THEN** the system rejects the change with a "weak password" error and changes nothing

### Requirement: Hashing happens only past the identity guard

The system SHALL NOT hash the new password until the current-password verification has succeeded, so the
expensive hash is never paid for a request that the identity guard would reject. The new password's policy
validation (cheap and pure) is the only credential work that precedes the guard.

#### Scenario: A rejected guard performs no hashing

- **WHEN** the current password is wrong (or the requester resolves to no active person)
- **THEN** the system rejects before hashing the new password and the stored hash is unchanged

### Requirement: A successful change purges every other session and preserves the acting one

On a successful password change the system SHALL purge **all** of the person's sessions **except** the one
the request was made on (identified by the current session's token), so any token issued before the change
stops resolving while the acting session stays live. The kept session SHALL remain valid; every other
session — live, revoked, or expired — SHALL be removed. The purge SHALL be idempotent: a person whose only
session is the acting one is a valid no-op.

#### Scenario: Other sessions are dropped, the current one survives

- **WHEN** a person with several live sessions changes their password from one of them
- **THEN** every other session of that person stops resolving, and the session the change was made on still
  authenticates

#### Scenario: A stolen older token stops working

- **WHEN** a password change succeeds
- **THEN** a token that was issued before the change (and is not the acting session) no longer resolves to a
  live session

### Requirement: Changing the password touches no identity, status, or ledger

The system SHALL NOT modify the person's `name`, `email`, `status`, `id`, or `created_at`, and SHALL NOT
modify, relink, or delete any of the person's budgets, expenses, or pairs as part of a password change. A
password change alters only the stored hash and the person's other sessions.

#### Scenario: Identity and ledger are preserved

- **WHEN** a person changes their password
- **THEN** their name, email, status, id, created_at, budgets, expenses, and pairs are unchanged after the
  change

