# dissolve-pair Specification

## Purpose
TBD - created by archiving change dissolve-pair. Update Purpose after archive.
## Requirements
### Requirement: Dissolve the requester's live pair

The system SHALL let a person dissolve the live pair they belong to. Dissolving soft-deletes the `Pair`
by stamping its `deleted_at` with the current instant and persisting it; the pair is thereafter no longer
live. The system SHALL touch **only** the pair's `deleted_at` — no budget, expense, invite, or person is
read, modified, moved, or deleted as part of dissolving.

#### Scenario: Requester is person_a of a live pair

- **WHEN** a requester who is `person_a` of a live pair (`deleted_at` null) dissolves it
- **THEN** the pair's `deleted_at` is stamped with the current instant
- **AND** the pair is persisted in its dissolved state
- **AND** no budget, expense, or invite belonging to either partner is changed

#### Scenario: Requester is person_b of a live pair

- **WHEN** a requester who is `person_b` of a live pair (`deleted_at` null) dissolves it
- **THEN** the pair's `deleted_at` is stamped with the current instant
- **AND** the pair is persisted in its dissolved state

### Requirement: Only a member of the live pair can dissolve it

The system SHALL resolve the pair to dissolve **by the requester**, returning only a live pair the
requester belongs to (`person_a` or `person_b`). A requester who is in no live pair has no couple to
dissolve and SHALL be rejected with `NotPairedError`. There SHALL be no path by which a person dissolves a
pair they are not a member of.

#### Scenario: Requester is in no live pair

- **WHEN** a requester who belongs to no live pair attempts to dissolve a pair
- **THEN** the system raises `NotPairedError`
- **AND** nothing is persisted or changed

#### Scenario: Requester's only pair is already dissolved

- **WHEN** a requester whose only pair was previously dissolved attempts to dissolve again
- **THEN** the system raises `NotPairedError` (the already-dissolved pair is not live, so it is not found)
- **AND** nothing is persisted or changed

### Requirement: The single-live-pair invariant is preserved and re-pairing is allowed

Dissolving SHALL be the only transition out of a pair's live state. A dissolved pair SHALL never block a
future pairing: it is excluded from the requester's live-pair lookup, so the same two people — or either of
them with a new partner — MAY pair again afterward, forming a **new** pair with a new id. A person SHALL be
in at most one live pair at any time; any number of dissolved pairs MAY remain in their history.

#### Scenario: Re-pairing after dissolve succeeds

- **WHEN** a pair is dissolved and one of its former members later accepts a valid invite
- **THEN** the live-pair lookup finds no live pair for that person, so pairing proceeds
- **AND** a new pair (new id) is formed, leaving the dissolved pair untouched in history

#### Scenario: Dissolved pair stays out of the live view

- **WHEN** a pair has been dissolved
- **THEN** the requester's live-pair lookup returns nothing for either former member
- **AND** the couple reads (couple-expenses, couple-budget) find no live pair to look through

