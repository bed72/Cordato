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

## String Resource Naming

Use `<type>_<context>_<description>` in English `snake_case`. Keep strings in
`res/values/strings_<context>.xml`; `strings.xml` is reserved for the `app` context.
Group entries by type inside each file, separated by blank lines. Do not mix
strings with colors, styles or other resource types.

| Prefix | Purpose | Example |
| --- | --- | --- |
| `failure_` | Validation failures | `failure_authentication_invalid_email` |
| `success_` | Successful operation feedback | `success_authentication_email_sent` |
| `label_` | UI names, titles, labels and descriptions | `label_home_widget_name` |
| `action_` | Buttons and other action text | `action_home_widget_add_expense` |
| `cd_` | Accessibility descriptions | `cd_home_widget_monthly_summary` |
| `msg_` | General messages, hints, toasts and snackbars | `msg_home_widget_update_required` |
| `config_` | Technical configuration, not user-facing text | `config_authentication_link_host` |

Current contexts are `app`, `authentication`, `common` and `home_widget`. Use
`common` only for truly shared text, not as a catch-all. Keep authentication URL
components together, with `translatable="false"`; the same applies to invariant
brand names, currency symbols and symbol-only actions. Preserve numbered format
arguments such as `%1$s` and `%2$s` when renaming or translating resources.
Accessibility descriptions have their own `cd_` resources rather than borrowing
a UI label. New prefixes or contexts require updating this convention and its
architecture tests; do not create empty files or placeholder strings for unused
message types. Resources in localized `values-*` directories retain the same
names and context filenames as their default counterparts.

`test/architecture/android_string_resources_test.dart` checks naming, context
separation, duplicate declarations, non-translatable technical values and native
references. App-link contract tests also verify the exact paths and host.

Verification after the resource reorganization: `flutter pub get` succeeded,
`flutter analyze` reported no issues, `flutter test --reporter failures-only`
passed all 1401 tests, and `flutter build apk --debug` succeeded. The previously
documented `home_widget` Kotlin-plugin warning remains non-blocking.

## Build And Verify

The home-screen widget is registered as `.AddExpenseWidgetProvider`, with a 2×2
RemoteViews layout showing the current month, last synchronized monthly total,
and **+ Nova despesa**. The action uses the app's primary/on-primary colors,
centered text and 14dp corners rather than a capsule. Resizing is enabled on both
axes, down to a requested height of 56dp, subject to the launcher's grid. Short
widgets use tighter spacing; wide widgets place the action beside the summary.
Below 96dp tall, the layout is horizontal with inline currency; below 300dp wide
as well, the action is hidden and the summary uses the full inner width. The
whole widget remains tappable to open New expense, with its accessible description.
Horizontal padding stays at 16dp even in a single row; vertical padding alone
shrinks to 4dp. Narrow single-row money without an action starts at 15; wide single-row
money retains 16. Vertical layouts use 19, capped at 21 for accessibility, while
regular horizontal layouts retain 22, capped at 26. Money can shrink further to
keep all digits inside the padded summary rather than pressing against the edges.
There are no background HTTP requests. A local inexact alarm
and date/time-zone broadcasts re-render month changes, subject to OS scheduling.
Install a fresh
build and add **Adicionar despesa** from the launcher's widget picker. Its single
tap action is delivered through `home_widget`, not Flutter's automatic deep-link
handler. `MainActivity` disables automatic deep linking only for that plugin
action; verification and password-reset app links keep their existing handling.

Before release, manually verify cold/warm launches, logged-out continuation after
sign-in, creation form deduplication with unsaved input, editing versus creation,
return to Dashboard after saving/back, and system light/dark themes.
Also verify current-month totals while Dashboard uses a historical filter, a
successful empty month, network failures retaining cached totals, logout clearing
the summary, and month rollover showing **Abra para atualizar** until a new sync.
`AddExpenseWidgetProvider` separates lifecycle, JSON parsing, BRL formatting,
RemoteViews composition and alarm management; formatting keeps cents as integers
and uses BigDecimal rather than floating-point money.
Amounts remain complete, including cents. Paint measures available text width;
the currency moves to its own line when needed, except in short narrow widgets.
The numeric font then scales to fit without abbreviation or ellipsis. Extreme
values may require small text; accessibility retains the full amount.

Run native formatting and dimension-policy tests from the repository root:

```bash
dart run tool/test_home_widget_native.dart android
```

JUnit tests compile the production Kotlin policy without mounting UI. They cover
zero, signed cents, 15-million boundaries, Long limits, short/wide/tall dimensions
and measured-width font adaptation. Manually check rendering with long amounts,
large accessibility text and the stale-summary hint before distribution.

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

If Gradle cannot start the Flutter subprocess and the stack trace reports
`Failed to exec spawn helper`, check whether Android Studio or its bundled JDK
was updated while a Gradle daemon was running. Restart the daemons from the
repository root, then retry the build:

```bash
./android/gradlew -p android --stop
flutter build apk --debug
```

Use `flutter doctor -v` to identify Flutter's actual Java executable; it may use
Android Studio's bundled JDK even when `java -version` in the terminal uses
another JDK. This failure was reproduced with a daemon older than its updated
`jspawnhelper` and resolved by restarting the daemons. Disabling the daemon is
not required. Native-access and Kotlin-plugin warnings are separate from this
process-start failure.

### Native Access And Built-In Kotlin

The Unix and Windows Gradle wrapper scripts are versioned and set
`--enable-native-access=ALL-UNNAMED` for the launcher JVM. `org.gradle.jvmargs`
sets it for the daemon as well; setting only the daemon flag leaves the launcher
warning on newer JDKs. This grants Gradle's required native access rather than
suppressing warnings or changing the machine-wide JDK configuration.

`android.builtInKotlin=true` enables AGP's built-in Kotlin. The app does not apply
external KGP, and `home_widget` 0.10.0 supports this flag without modifying the
pub cache. `android.newDsl=false` remains for existing DSL compatibility.

Flutter 3.47.9 scans dependency build scripts using regex and still warns about
`home_widget` because the inactive conditional branch contains `apply plugin:
'kotlin-android'`. Runtime inspection confirmed that neither `kotlin-android`
nor `org.jetbrains.kotlin.android` is applied to that subproject with built-in
Kotlin enabled. Eliminating that remaining false positive requires an upstream
tooling/package fix; do not hide it by disabling dependency validation or editing
the pub cache.

Messages about engine flags passed via Intent are emitted by Flutter's Android
embedding during CLI debug launches. Impeller, viewport and VM Service messages
are normal debug diagnostics, not application build failures.

### Distribution Artifacts

Build the 1.0.0 (5) Android App Bundle for internal testing, explicitly using
the PocketBase API validated by the local release login:

```bash
flutter build appbundle --release \
  --build-name=1.0.0 \
  --build-number=5 \
  --dart-define=BASE_URL=https://pocketbase.cordato.cloud/api/
```

Use a higher build number for subsequent uploads. After publishing to internal
testing, install or update through the tester's Google Play link, confirm that
version code 5 is installed, and verify sign-in and the native widget. Local
release success does not by itself validate the artifact distributed by Play.

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

### Focus And Splash Verification

After making keyboard-next destinations explicit and aligning Flutter splash
assets with native images, `flutter pub get`, `flutter analyze` and
`flutter test --reporter failures-only` passed (1405 tests). Android debug APK
and unsigned iOS simulator builds with the PocketBase `BASE_URL` also succeeded.
Manual Maestro hierarchy inspection on a moto g05 with Android 15 confirmed that
Next moves from email to password and keeps the keyboard open in sign-in and
sign-up. No Maestro flows or UI tests were added. The original intermittent
sign-in failure was not reproduced before the change; this is not verification
of every device or the Google Play release. The previously generated build 5 AAB
predates these focus/splash changes and must not be presented as containing them.

## App Links

Para App Links, publique o SHA-256 do certificado efetivo de distribuição em
`https://app.cordato.cloud/.well-known/assetlinks.json`, associado ao pacote
`com.bed.cordato` pela relação `delegate_permission/common.handle_all_urls`.
Para Google Play, usar o certificado de App Signing, não apenas o de upload.
O manifest já declara `autoVerify` para `/authentication/confirm-email`.
Geração dos arquivos públicos, configuração iOS, ordem de ativação do template
PocketBase e homologação estão em [app_links/README.md](../app_links/README.md).

## Key Rotation

Keep the release keystore in the approved secret store and restrict access to
authorized maintainers. When rotating a key, replace the keystore and all four
local or environment values together, build a new artifact, and verify its
certificate before distribution. Android signing keys may be constrained by the
distribution channel, including Google Play App Signing; coordinate any key
replacement with that channel before publishing.
