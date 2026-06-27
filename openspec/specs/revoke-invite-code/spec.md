# revoke-invite-code Specification

## Purpose
TBD - created by archiving change revoke-invite-code. Update Purpose after archive.

## Requirements
### Requirement: A creator can revoke their own pending invite code

The system SHALL revoke an invite given its `code` token and the requesting person (`requester_id`). When the
token matches an invite the requester created and that invite is neither consumed nor already revoked, the
system SHALL stamp the code's `revoked_at` with the instant obtained from the clock port, persist it, and
report success. A revoked code is no longer redeemable. Revocation is **read at request-time and mutates only
the targeted code**; it forms, consumes, or dissolves no pair.

#### Scenario: A pending code is revoked

- **WHEN** the creator of a code that is not expired-consumed-or-revoked requests its revocation by token
- **THEN** the system stamps that code's `revoked_at` with the current instant and reports success

#### Scenario: Revoking does not touch pairs

- **WHEN** a code is revoked
- **THEN** no pair is created, consumed, or dissolved as a result

### Requirement: Only the code's creator may revoke it

The system SHALL revoke a code only at the request of the person whose `creator_id` minted it. A request whose
`requester_id` is not the code's creator SHALL be rejected as **invite-not-found**, with a short pt-BR message
that does not reveal whether the token exists — identical to the rejection of an unknown token, so revocation
leaks no information about other people's invites.

#### Scenario: A non-owner request is rejected as not-found

- **WHEN** a person who did not create the code requests its revocation by that code's token
- **THEN** the system rejects the request with an invite-not-found error and the code's `revoked_at` stays
  unchanged

#### Scenario: An unknown token is rejected as not-found

- **WHEN** a person requests revocation of a token that matches no stored invite
- **THEN** the system rejects the request with the same invite-not-found error, revealing nothing about token
  existence

### Requirement: A consumed code cannot be revoked

The system SHALL reject revocation when the matched code already has a non-null `consumed_at`. A consumed code
has already formed a pair; that pairing is undone only by dissolving the pair, never by revoking the spent
code.

#### Scenario: Revoking a consumed code is rejected

- **WHEN** the creator requests revocation of a code whose `consumed_at` is already set
- **THEN** the system rejects the request with an invite-already-consumed error and the code's `revoked_at`
  stays null

### Requirement: Revoking an already-revoked code is idempotent

The system SHALL treat the revocation of an already-revoked code as a successful no-op: it SHALL NOT raise and
SHALL NOT overwrite the existing `revoked_at`, preserving the original revocation instant. Revoking twice
converges on the same terminal state.

#### Scenario: Re-revoking preserves the original instant

- **WHEN** the creator revokes a code that already has a non-null `revoked_at`
- **THEN** the system reports success and the code's `revoked_at` remains the instant of the first revocation,
  unchanged

### Requirement: Expiry does not block revocation

The system SHALL allow revoking a code that is past its `expires_at`, provided it is neither consumed nor
already revoked. Expiry is a time-derived fact, not a creator action; killing a soon-to-expire or just-expired
token is still a valid revocation.

#### Scenario: An expired but unconsumed code can be revoked

- **WHEN** the creator revokes a code whose `expires_at` is at or before the current instant and which is
  neither consumed nor revoked
- **THEN** the system stamps its `revoked_at` and reports success
