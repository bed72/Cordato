## ADDED Requirements

### Requirement: A newly minted invite code starts un-revoked

The system SHALL create every invite code with `revoked_at` set to null. Revocation is a creator action taken
later (the `revoke-invite-code` capability); a freshly minted code has never been revoked, so its `revoked_at`
begins null exactly as its `consumed_at` does.

#### Scenario: A new code starts un-revoked

- **WHEN** an invite code is created
- **THEN** its `revoked_at` is null (the code has not been revoked)
