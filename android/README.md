# Android Release

Android release builds require a dedicated signing key. Never use the Android
debug key or commit signing material, passwords, aliases, or `key.properties`.

## Signing Configuration

Use one of the following secure configuration boundaries. Environment variables
take precedence over `android/key.properties`, allowing the same tracked Gradle
configuration to be used locally and by an automated release environment.

Create the ignored `android/key.properties` file locally:

```properties
storeFile=/absolute/path/to/cordato-release.jks
storePassword=replace-with-store-password
keyAlias=replace-with-key-alias
keyPassword=replace-with-key-password
```

Or supply all required environment variables:

```bash
export ANDROID_RELEASE_STORE_FILE=/secure/path/cordato-release.jks
export ANDROID_RELEASE_STORE_PASSWORD=...
export ANDROID_RELEASE_KEY_ALIAS=...
export ANDROID_RELEASE_KEY_PASSWORD=...
```

The build fails during `preReleaseBuild` when a value is missing or the
keystore path does not exist. This prevents release artifacts from falling back
to debug signing.

## Build And Verify

The default production API is `https://app.cordato.cloud/api/`, matching the
release launch configuration. To explicitly pin it when building an APK:

```bash
flutter build apk --release --dart-define=BASE_URL=https://app.cordato.cloud/api/
```

Android builds require JDK 21. Confirm that Flutter and Gradle are using it:

```bash
flutter doctor -v
./gradlew -version
```

Build an Android App Bundle for distribution:

```bash
flutter build appbundle --release
```

The artifact is `build/app/outputs/bundle/release/app-release.aab`. To build an
APK instead, run `flutter build apk --release`; the artifact is
`build/app/outputs/flutter-apk/app-release.apk`.

Verify the certificate with the JDK tool, using the same secure signing
configuration:

```bash
keytool -list -v -keystore "$ANDROID_RELEASE_STORE_FILE" \
  -alias "$ANDROID_RELEASE_KEY_ALIAS"
```

For an APK, also inspect the artifact directly:

```bash
apksigner verify --verbose --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
```

Confirm the merged release manifest contains the production network permission:

```bash
grep -F 'android.permission.INTERNET' \
  build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml
```

The exact merged-manifest directory is Android Gradle Plugin-version specific;
use the generated `build/app/intermediates/` path if this location changes.

## App Links

Para App Links, publique o SHA-256 do certificado efetivo de distribuição em
`https://app.cordato.cloud/.well-known/assetlinks.json`, associado ao pacote
`com.bed.cordato` pela relação `delegate_permission/common.handle_all_urls`.

## Key Rotation

Keep the release keystore in the approved secret store and restrict access to
authorized maintainers. When rotating a key, replace the keystore and all four
local or environment values together, build a new artifact, and verify its
certificate before distribution. Android signing keys may be constrained by the
distribution channel, including Google Play App Signing; coordinate any key
replacement with that channel before publishing.
