# create-invite-code Specification

## Purpose
Minting a single-use invite code is the first step of pairing: a person creates a short, unpredictable
token that a partner will later redeem to form the couple. This capability covers only the creation of the
code — generating the CSPRNG token, fixing its ~1-day expiry as a domain rule, starting it unconsumed, and
returning its public data. Redeeming a code (and creating the `Pair`) is a separate capability.

## Requirements
### Requirement: A creator can mint a single-use invite code

The system SHALL create a new invite code for a given creator (`creator_id`). The code SHALL be persisted
with an opaque `id` and a timezone-aware `created_at` obtained from the determinism ports, a `creator_id`
equal to the requesting creator, a generated `code` token, an `expires_at`, and `consumed_at` set to null.
The system SHALL return the new code's public data. The `creator_id` SHALL be stored exactly as given;
verifying that it refers to an existing, active person is out of scope for this capability.

#### Scenario: A code is minted for the creator

- **WHEN** a creator requests a new invite code
- **THEN** the system persists an invite code whose `creator_id` is that creator, with an assigned `id`
  and `created_at`, and returns its public data

#### Scenario: A new code starts unconsumed

- **WHEN** an invite code is created
- **THEN** its `consumed_at` is null (the code is available to be redeemed later)

### Requirement: The invite code token is short and unpredictable

The system SHALL generate the `code` token from a cryptographically secure pseudo-random source (CSPRNG).
The token SHALL be a short, URL-safe string and SHALL NOT be sequential, time-derived, or otherwise
predictable from other codes. Each created code SHALL receive a freshly generated token.

#### Scenario: The token comes from a cryptographic source

- **WHEN** an invite code is created
- **THEN** its `code` is a short token drawn from a CSPRNG, not derived from the `id`, the timestamp, or a
  counter

#### Scenario: Two codes get distinct tokens

- **WHEN** two invite codes are created
- **THEN** each receives its own independently generated token

### Requirement: The invite code expires about one day after creation

The system SHALL set `expires_at` to approximately one day after `created_at`. This time-to-live SHALL be a
domain rule fixed by the invite-code factory, derived from the creation instant rather than supplied by the
caller. The actual enforcement of expiry (rejecting an expired code) belongs to the redeem/accept
capability and is out of scope here; this capability only stamps the expiry.

#### Scenario: Expiry is one day past creation

- **WHEN** an invite code is created with a given `created_at`
- **THEN** its `expires_at` equals that `created_at` plus the fixed one-day time-to-live

#### Scenario: Expiry is not caller-supplied

- **WHEN** a creator requests a new invite code
- **THEN** the creator cannot set or influence `expires_at`; it is derived solely from `created_at`

### Requirement: A newly minted invite code starts un-revoked

The system SHALL create every invite code with `revoked_at` set to null. Revocation is a creator action taken
later (the `revoke-invite-code` capability); a freshly minted code has never been revoked, so its `revoked_at`
begins null exactly as its `consumed_at` does.

#### Scenario: A new code starts un-revoked

- **WHEN** an invite code is created
- **THEN** its `revoked_at` is null (the code has not been revoked)
