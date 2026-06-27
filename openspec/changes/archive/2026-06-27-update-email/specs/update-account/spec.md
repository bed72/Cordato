## REMOVED Requirements

The `update-account` capability is removed and split into two: its name edit becomes `update-name`, and its
email edit becomes the credential-sensitive `update-email`. The combined single-request name+email update no
longer exists (**BREAKING**). Every requirement below is retired; its behavior is re-stated — and, for email,
hardened with a current-password re-confirmation and a session purge — in the two replacement capabilities.

### Requirement: An authenticated person updates their own account in place

**Reason**: Split. The name half moves to `update-name` ("An authenticated person updates their own name in
place"); the email half moves to `update-email` ("An authenticated person changes their own email in place"),
now guarded by the current password. There is no longer a single transition that edits both fields at once.

**Migration**: Send the name to `update-name`; send the email (with the current password) to `update-email`.

### Requirement: Only the acting person can update their account, and the lookup is the authorization

**Reason**: Carried into both replacements. `update-name` keeps the identical lookup-is-authorization rule
(unresolved requester → "invalid session"). `update-email` strengthens it: the requester is re-confirmed by
the current password, and an unresolved requester fails identically to a wrong password ("incorrect
password", no oracle).

**Migration**: None beyond using the two new use cases; per-person authorization is preserved in both.

### Requirement: Email is re-validated and normalized

**Reason**: Moved verbatim to `update-email` ("The new email is re-validated and normalized").

**Migration**: None; identical validation and normalization apply under `update-email`.

### Requirement: Name is re-validated

**Reason**: Moved verbatim to `update-name` ("Name is re-validated").

**Migration**: None; identical name validation applies under `update-name`.

### Requirement: Email stays unique among active accounts, excluding the acting person

**Reason**: Moved verbatim to `update-email` ("Email stays unique among active accounts, excluding the acting
person"), including the non-enumeration guarantee and the freed-email reuse allowance.

**Migration**: None; identical uniqueness rule applies under `update-email`.

### Requirement: Updating an account touches no credentials, status, identity, or ledger

**Reason**: Split into the two replacements' scoping rules. `update-name` touches only the name (credential,
email, status, identity, sessions, and ledger untouched). `update-email` touches only the email **and** the
person's other sessions (it purges every session except the acting one), leaving credential, name, status,
identity, and ledger untouched.

**Migration**: None; both replacements preserve identity and ledger. Note the one intended new effect:
`update-email` now purges the person's other sessions, which `update-account` did not.
