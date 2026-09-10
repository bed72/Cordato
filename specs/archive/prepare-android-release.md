# Prepare Android Release

## Status

Archived. Release hardening is implemented; generating and inspecting an
artifact with the authorized release keystore remains an operational step.

## Objective

Make Android release builds network-capable, uniquely signed, and reproducible without committing private signing
material. A release artifact must not silently inherit debug-only permissions or the debug signing key.

## Scope

- Declare the permissions required by the production app in the main Android manifest.
- Configure a release signing configuration that obtains credential values from local untracked configuration or
  the release environment.
- Make a release build fail clearly when required signing material is unavailable.
- Document local and automated release-build setup, artifact verification, and key rotation responsibilities.
- Verify the final merged release manifest and APK/AAB signing identity.

## Non-goals

- Do not commit a keystore, passwords, aliases, signing files, or credentials.
- Do not change package identity, deep-link behavior, Android minimum/target SDK, store listing, CI, or iOS
  signing.
- Do not add runtime permissions unless the product actually requires them.

## Requirements

### Requirement: Release manifest contains production network permission
The main Android manifest SHALL declare the network permission required by Supabase and other production API
communication. The release variant SHALL not depend on debug or profile manifest overlays for that permission.

#### Acceptance scenarios

- **WHEN** Gradle merges the release manifest
- **THEN** the resulting manifest SHALL contain `android.permission.INTERNET`

- **WHEN** a debug or profile overlay is removed or changed
- **THEN** the release variant SHALL retain the network permission from the main manifest

### Requirement: Release artifacts use a non-debug signing identity
The release build type SHALL use a dedicated release signing configuration and SHALL not use the Android debug
keystore. Signing values SHALL be supplied from an ignored local configuration file or release environment
variables.

#### Acceptance scenarios

- **WHEN** a properly configured release build is assembled
- **THEN** the generated APK or AAB SHALL be signed with the configured release certificate

- **WHEN** a release build is requested without complete signing configuration
- **THEN** the build SHALL fail before producing an artifact signed with the debug key

- **WHEN** source control is inspected
- **THEN** no keystore, key password, store password, or signing configuration containing secrets SHALL be tracked

### Requirement: Release setup and verification are documented
The repository SHALL document how an authorized maintainer supplies signing material, builds a release artifact,
verifies its signing certificate, and rotates or replaces a compromised key without embedding credentials in
source control.

#### Acceptance scenarios

- **WHEN** an authorized maintainer follows the documented release procedure
- **THEN** they SHALL be able to produce and inspect a signed release artifact without editing tracked Gradle
  files for secrets

- **WHEN** a signing credential is rotated
- **THEN** the documentation SHALL identify the configuration boundary that must be updated and the artifact
  verification step that confirms the new identity

## Dependencies

- Access to the intended Android release keystore or an approved process for creating one.
- A secure local or release-environment secret distribution mechanism.

## Verification

- Inspect the merged release manifest for `android.permission.INTERNET`.
- Attempt a release build without credentials and confirm it fails safely.
- Build a release artifact with authorized credentials and inspect its signing certificate.
- Confirm ignored files prevent signing material from appearing in Git status.
