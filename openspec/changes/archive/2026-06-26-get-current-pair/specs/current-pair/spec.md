# current-pair Specification

## ADDED Requirements

### Requirement: A person can read their own current pair

The system SHALL return, for a given `reader_id`, that person's **live** pair resolved from the reader's
own perspective — the partner's identity (`partner_id`, `partner_name`) together with the pair's `pair_id`
and `paired_since` (the pair's `created_at`). The read is **read-only** and read at request-time; producing
it SHALL NOT mutate the ledger. The partner is **"the member of the pair who is not the reader"** — a
reader-relative derivation, never a stored field.

#### Scenario: The reader is the pair's first member

- **WHEN** a person who is `person_a` of a live pair reads their current pair
- **THEN** the system returns the pair's `pair_id` and `paired_since`, with `partner_id` and `partner_name` being `person_b`'s identity

#### Scenario: The reader is the pair's second member

- **WHEN** a person who is `person_b` of a live pair reads their current pair
- **THEN** the system returns the pair's `pair_id` and `paired_since`, with `partner_id` and `partner_name` being `person_a`'s identity

### Requirement: Not being paired is a valid answer, not an error

The system SHALL return **nothing** when the reader is in no live pair — this is a *status* read, so the
absence of a pair is the answer, never an error. It SHALL NOT raise `NotPairedError`; that error remains
the guard of the couple *views* (`couple-budget`, `couple-expenses`), which cannot exist without a pair.
A pair the reader once had but which is now dissolved (soft-deleted) counts as no live pair.

#### Scenario: A person who never paired

- **WHEN** a person who is in no pair at all reads their current pair
- **THEN** the system returns nothing, raising no error

#### Scenario: A person whose only pair was dissolved

- **WHEN** a person whose every pair has `deleted_at` set reads their current pair
- **THEN** the system returns nothing, raising no error

### Requirement: A person reads only their own pair

The system SHALL resolve the pair from the requesting `reader_id` alone, returning only the pair that
`reader_id` belongs to. Reading a pair grants no view over anyone else's pairing; a person can never read a
pair they are not a member of.

#### Scenario: The pair belongs to the requester

- **WHEN** a person reads their current pair while other people are paired among themselves
- **THEN** the system returns only the pair the requester is a member of, never another couple's

### Requirement: A live pair resolves to an active partner

The system SHALL resolve the partner's `partner_name` through the identity directory. A live pair
guarantees an active partner — deleting an account dissolves the pair — so the partner profile is expected
present. If the partner cannot be resolved while the pair is live, the system SHALL treat it as an
integrity violation rather than silently return a nameless pair.

#### Scenario: The partner's name is resolved

- **WHEN** a person reads their live pair and the partner is an active person
- **THEN** the returned `partner_name` is that partner's current name

#### Scenario: A live pair whose partner cannot be resolved

- **WHEN** a person reads their live pair but the partner's profile cannot be resolved
- **THEN** the system raises an integrity error rather than returning a pair with no partner name
