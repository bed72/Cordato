## ADDED Requirements

### Requirement: Deleting an account is guarded by the requester's password

The system SHALL require the requester to re-confirm their identity by supplying their raw password, and
SHALL verify it against the person's stored hash **before** any data is read, erased, or modified. A
mismatch SHALL reject the deletion with `IncorrectPasswordError` (a pt-BR, non-leaking message) and SHALL
leave every budget, expense, pair, and the person itself completely untouched. The password verification
SHALL be the first step, so that a failed guard pays for no destructive work.

#### Scenario: Correct password authorizes the deletion

- **WHEN** a requester supplies the password that matches their stored hash
- **THEN** the system proceeds with the deletion
- **AND** the raw password is verified against the hash via the hasher port, never compared as plaintext

#### Scenario: Wrong password rejects the deletion and changes nothing

- **WHEN** a requester supplies a password that does not match their stored hash
- **THEN** the system raises `IncorrectPasswordError`
- **AND** no budget, expense, or pair is erased, modified, or dissolved
- **AND** the person's status, email, and hash are unchanged

### Requirement: Deletion physically erases the person's budgets and expenses

The system SHALL physically delete (cascade) **all** of the requester's budgets and expenses — both live and
already soft-deleted rows — so the person's ledger ceases to exist. This is the domain's **only** physical
deletion: unlike day-to-day removal, account deletion sets no `deleted_at`; the rows are gone. No other
person's budgets or expenses SHALL be read or touched, because no datum is owned by anyone but its single
owner.

#### Scenario: All of the person's ledger is purged

- **WHEN** a deletion proceeds (after a correct password)
- **THEN** every budget owned by the requester is physically removed
- **AND** every expense owned by the requester is physically removed
- **AND** no row belonging to any other person is read or affected

#### Scenario: A partner's data is untouched by the deletion

- **WHEN** a requester who is in a live pair deletes their account
- **THEN** only the requester's own budgets and expenses are erased
- **AND** the partner keeps every budget and expense they own, intact

### Requirement: Deletion neutralizes the email and retires the account

The system SHALL retire the account in one transition: replace the person's email with a collision-free
sentinel derived from the person's id (a still-valid email address, e.g. `deleted+<id>@…`) and set
`status = deleted`. A retired account SHALL no longer authenticate. Neutralizing the email SHALL free the
original address for reuse: it no longer belongs to any active person.

#### Scenario: The account is marked deleted and its email neutralized

- **WHEN** a deletion proceeds
- **THEN** the person's `status` becomes `deleted`
- **AND** the person's email is replaced with a sentinel derived from their id
- **AND** the retired person is persisted in that state

#### Scenario: The freed email becomes available again

- **WHEN** an account holding a given email is deleted
- **THEN** that original email is no longer held by any active person
- **AND** a subsequent registration with the same email succeeds, creating a brand-new person with a new id
  and an empty ledger
- **AND** the new person does not inherit any budget, expense, or pair of the deleted one

### Requirement: Deletion dissolves any live pair as a consequence

The system SHALL dissolve the requester's live pair as a consequence of the deletion, by composing the
existing dissolve building block. This step SHALL be **idempotent**: a requester who is in no live pair is a
no-op here — deletion still succeeds. Dissolving SHALL only soft-delete the `Pair`; it SHALL move or destroy
no budget or expense of either partner.

#### Scenario: A live pair is dissolved on deletion

- **WHEN** a requester who belongs to a live pair deletes their account
- **THEN** that pair is dissolved (soft-deleted)
- **AND** the former partner is no longer in a live pair and keeps all of their own data

#### Scenario: Deletion succeeds when the requester is in no live pair

- **WHEN** a requester who belongs to no live pair deletes their account
- **THEN** the deletion still completes (ledger erased, account retired, email neutralized)
- **AND** the dissolve step is a no-op, raising no error

### Requirement: Account deletion is irreversible

The system SHALL provide no path to restore a deleted account or its erased ledger. A deleted person SHALL
remain retired; the only way to use the freed email again is to register a **new** person, which shares
nothing with the deleted one.

#### Scenario: There is no restore

- **WHEN** an account has been deleted
- **THEN** no operation restores the person, their budgets, their expenses, or their former pair
- **AND** reusing the freed email creates an unrelated new person (new id, empty ledger)
