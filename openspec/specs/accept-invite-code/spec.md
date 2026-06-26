# accept-invite-code Specification

## Purpose
Redeeming a valid invite is the step that brings a couple into existence: it consumes a single-use code
and forms the `Pair` — the keystone the entire shared view depends on. This capability covers matching the
token to a live, unexpired, unconsumed code; rejecting self-pairing, an already-paired creator or accepter,
and inactive people; and then atomically consuming the code and creating the live `Pair` between creator
and accepter. Minting the code is a separate capability; dissolving the pair and the couple views are
separate capabilities still.

## Requirements
### Requirement: Accepting a valid invite forms the pair and consumes the code

The system SHALL accept an invite given a `code` token and an accepting person (`accepter_id`). When the
code is valid for redemption and every pairing invariant holds, the system SHALL, as a single redemption:
stamp the code's `consumed_at` with the redemption instant obtained from the clock port; create a new
`Pair` whose `person_a_id` is the code's `creator_id`, whose `person_b_id` is the `accepter_id`, with an
opaque `id` and a timezone-aware `created_at` from the determinism ports and `deleted_at` set to null; and
return the new pair's public data. A code is single-use: once consumed it can never form another pair.

#### Scenario: A valid invite forms the pair

- **WHEN** an active person accepts a code that exists, is not expired, and is not yet consumed, and
  neither the creator nor the accepter is already in a live pair, and the accepter is not the creator
- **THEN** the system creates a live `Pair` linking the creator (`person_a_id`) and the accepter
  (`person_b_id`) with an assigned `id` and `created_at` and `deleted_at` null, and returns its public data

#### Scenario: Accepting consumes the code

- **WHEN** an invite is successfully accepted
- **THEN** the code's `consumed_at` is set to the redemption instant, so the same code cannot be redeemed
  again

### Requirement: The code must match a known invite

The system SHALL reject acceptance when the supplied `code` token matches no invite. The rejection SHALL
carry a short pt-BR message that does not reveal whether a token exists, was mistyped, or expired.

#### Scenario: Unknown token is rejected

- **WHEN** a person accepts a `code` that matches no stored invite
- **THEN** the system rejects the acceptance with an invite-not-found error, no pair is created, and no
  code is consumed

### Requirement: An expired invite cannot be redeemed

The system SHALL reject acceptance when the matched code's `expires_at` is at or before the redemption
instant from the clock. Expiry enforcement belongs to this capability (the minting capability only stamps
the expiry). A code whose `expires_at` is strictly after the redemption instant is still live.

#### Scenario: Expired code is rejected

- **WHEN** a person accepts a code whose `expires_at` is at or before the current instant
- **THEN** the system rejects the acceptance with an invite-expired error, no pair is created, and the code
  is not consumed

#### Scenario: A code on its last moment is still live

- **WHEN** a person accepts a code whose `expires_at` is strictly after the current instant
- **THEN** the expiry check passes and redemption proceeds to the remaining invariants

### Requirement: A consumed invite cannot be redeemed again

The system SHALL reject acceptance when the matched code already has a non-null `consumed_at`. Single-use
is final: a redeemed code never forms a second pair.

#### Scenario: Already-consumed code is rejected

- **WHEN** a person accepts a code whose `consumed_at` is already set
- **THEN** the system rejects the acceptance with an invite-already-consumed error and no new pair is
  created

### Requirement: A person cannot pair with themselves

The system SHALL reject acceptance when the `accepter_id` equals the matched code's `creator_id`. A pair is
always between two distinct people.

#### Scenario: Self-pairing is rejected

- **WHEN** the accepter is the same person who created the code
- **THEN** the system rejects the acceptance with a self-pairing error, no pair is created, and the code is
  not consumed

### Requirement: Neither party may already be in a live pair

The system SHALL enforce the at-most-one-live-pair invariant: it SHALL reject acceptance when the creator
or the accepter already belongs to a pair with `deleted_at` null. Dissolved pairs in either person's
history SHALL NOT block a new pairing. The rejection message SHALL NOT reveal which party is already
paired.

#### Scenario: Accepter already paired is rejected

- **WHEN** the accepter is already in a live pair
- **THEN** the system rejects the acceptance with an already-paired error and no new pair is created

#### Scenario: Creator already paired is rejected

- **WHEN** the code's creator is already in a live pair
- **THEN** the system rejects the acceptance with an already-paired error and no new pair is created

#### Scenario: A dissolved past pair does not block

- **WHEN** the creator and the accepter each have only dissolved (soft-deleted) pairs in their history and
  none that is live
- **THEN** the at-most-one-live-pair invariant is satisfied and redemption proceeds

### Requirement: Both parties must be active people

The system SHALL confirm that both the creator and the accepter are active people before forming the pair,
and SHALL reject acceptance when either is not active. This confirmation SHALL be made through a port owned
by the pairing context — it SHALL NOT introduce any dependency from `pairing` on another feature module.
The rejection message SHALL NOT reveal which party is inactive.

#### Scenario: Inactive accepter is rejected

- **WHEN** the accepter is not an active person
- **THEN** the system rejects the acceptance with a person-not-active error and no pair is created

#### Scenario: Inactive creator is rejected

- **WHEN** the code's creator is not an active person
- **THEN** the system rejects the acceptance with a person-not-active error and no pair is created
