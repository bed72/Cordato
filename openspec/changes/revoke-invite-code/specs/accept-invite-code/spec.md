## ADDED Requirements

### Requirement: A revoked invite cannot be redeemed

The system SHALL reject acceptance when the matched code has a non-null `revoked_at`. A revoked code was
killed by its creator and is no longer redeemable — the same terminal treatment as an expired or consumed
code. The rejection SHALL carry a short pt-BR message that does not reveal whether the token exists, was
mistyped, expired, consumed, or revoked.

#### Scenario: Revoked code is rejected

- **WHEN** a person accepts a code whose `revoked_at` is already set
- **THEN** the system rejects the acceptance with an invite-revoked error, no pair is created, and the code is
  not consumed

#### Scenario: A non-revoked code still proceeds

- **WHEN** a person accepts a code whose `revoked_at` is null and which is otherwise valid for redemption
- **THEN** the revoked check passes and redemption proceeds to the remaining invariants
