# couple-expenses Specification

## Purpose
The couple is a point of view, not an owner — this capability is the first read-only couple-level view over
two individuals' ledgers. For a reader in a live pair it returns the union of both partners' live expenses,
each marked `mine` / `theirs` from the reader's perspective and ordered most-recent-first. It is a lens, not
a merge: nothing is stored, copied, or owned by the pair, the union is derived at read-time, and a reader in
no live pair has no view. Partner expenses are read through a port the `pairing` context owns, never a
cross-module dependency. Couple budget and pair dissolution are separate capabilities.

## Requirements
### Requirement: The couple expenses view is the union of both partners' expenses

The system SHALL return, for a reader (`reader_id`) who is in a live pair, the union of the live expenses
of **both** partners — the reader's own and the partner's. Each expense SHALL appear once, carrying its
own `id`, `person_id` (owner), `amount`, `occurred_on`, `description`, and `created_at`. The view is
**read-only** and **derived at read-time**: nothing is stored, copied, or owned by the pair, and forming
the union SHALL NOT mutate either ledger. The partner is the *other* person of the reader's live pair
(`person_b_id` when the reader is `person_a`, and vice versa).

#### Scenario: Both ledgers are combined

- **WHEN** a reader in a live pair requests the couple expenses and each partner has live expenses
- **THEN** the system returns one item per live expense of both partners, each preserving its own owner,
  amount, day, description, and identity

#### Scenario: One partner has no expenses

- **WHEN** a reader in a live pair requests the couple expenses and only one partner has live expenses
- **THEN** the system returns exactly that partner's live expenses and no others

#### Scenario: Neither partner has expenses

- **WHEN** a reader in a live pair requests the couple expenses and neither partner has any live expense
- **THEN** the system returns an empty view

#### Scenario: Soft-deleted expenses are excluded

- **WHEN** a partner has expenses that are soft-deleted
- **THEN** those expenses do not appear in the couple view

### Requirement: Each expense is marked from the reader's perspective

The system SHALL mark every expense in the view with a perspective relative to the reader: `mine` when the
expense's owner is the reader, and `theirs` when the owner is the partner. The perspective is **derived**
from the expense's owner and the reader's id — never stored. The same underlying expense SHALL be marked
`mine` for its owner and `theirs` for the other partner, so the view is always told from the point of view
of whoever is reading it.

#### Scenario: The reader's own expense is mine

- **WHEN** the view contains an expense whose owner is the reader
- **THEN** that expense is marked `mine`

#### Scenario: The partner's expense is theirs

- **WHEN** the view contains an expense whose owner is the partner
- **THEN** that expense is marked `theirs`

### Requirement: The view is ordered most-recent-first

The system SHALL order the combined view by `occurred_on` descending, breaking ties by `created_at`
descending, so the most recent spending appears first regardless of which partner it belongs to.

#### Scenario: Newer spending comes first

- **WHEN** the couple view contains expenses from both partners with different days
- **THEN** the expense with the later `occurred_on` appears before the earlier one

#### Scenario: Same-day expenses break ties by creation time

- **WHEN** two expenses share the same `occurred_on`
- **THEN** the one with the later `created_at` appears first

### Requirement: Only a reader in a live pair has a couple view

The system SHALL reject the request when the reader is in no live pair (`deleted_at` null) in which they
are `person_a` or `person_b`. A dissolved (soft-deleted) pair SHALL NOT grant a view: once the lens is
gone, there is no couple to look through. The rejection SHALL carry a short pt-BR message that does not
leak any partner's data.

#### Scenario: An unpaired reader is rejected

- **WHEN** a reader who belongs to no live pair requests the couple expenses
- **THEN** the system rejects the request with a not-paired error and returns no view

#### Scenario: A dissolved pair grants no view

- **WHEN** a reader whose only pair has been dissolved (soft-deleted) requests the couple expenses
- **THEN** the system rejects the request with a not-paired error and returns no view

### Requirement: Reading partner expenses crosses no module boundary

The system SHALL read each partner's expenses through a port owned by the `pairing` context, stated in
pairing's own vocabulary, and SHALL NOT introduce any dependency from `pairing` on the `expenses` module.
The concrete adapter that reads the underlying ledger is wired at the composition root — the only layer
permitted to know both modules.

#### Scenario: Pairing depends only on its own port

- **WHEN** the couple expenses are gathered
- **THEN** both partners' expenses are obtained through pairing's own reader port, with no import of the
  expenses feature from pairing's domain or application
