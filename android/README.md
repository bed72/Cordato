# Android Release

## Estado atual: versão local

Versão mínima: **Android 12 (API 31)**, fixada em `minSdk = 31` no
`app/build.gradle.kts`, sem depender do default do Flutter. compileSdk e
targetSdk permanecem inalterados; essa configuração se aplica aos próximos
artefatos, não modifica AABs já gerados pela CI.

Revisado em 24/11/2026. User/Expense/Metrics usam o mesmo Drift/SQLite, schema 1,
sem backend, login, sessão ou áudio. Composição e testes não dependem de
Localstore; Metrics agrega despesas diretamente no SQLite. Consulte o [README](../README.md) e a
[arquitetura](../ARCHITECTURE.md) para o estado canônico.
Os comandos e o workflow não exigem nem passam `BASE_URL`.
O manifest principal não declara `INTERNET`, `RECORD_AUDIO` ou app links de
autenticação. Debug/profile preservam a permissão de rede de desenvolvimento.
A ferramenta de associações e seus testes exclusivos foram removidos.
O widget continua usando `home_widget`, sem autenticação ou HTTP.
Builds assinados e comportamento distribuído ainda exigem homologação própria.

Na verificação de 24/11/2026: flutter analyze sem problemas e 1129 testes Flutter
aprovados. Os resultados intermediários da transição ficam no
[registro Drift](../docs/history/drift-transition.md).
Não houve novo build Android/iOS nem execução remota de release nesta entrega.
O teste de localtime com fusos distintos rodou no host,
não homologa datas/defaults no aparelho.

Os 39 testes Android/27 iOS e actionlint/plutil aprovados em 22/11/2026 são
[históricos](../docs/history/local-transition.md), anteriores a Drift. Permanecem
os avisos conhecidos de `android.newDsl=false` e da detecção de KGP em home_widget.
O workflow ainda exige LOCALSTORE_READ_TOKEN por um passo legado, embora o
pubspec atual não use o fork. Esse passo precisa de revisão separada antes de
retomar release; a integração de Metrics já está concluída. Esta atualização só documenta,
não altera YAML, secrets, assinatura, código de versão ou publicação.

Android release builds require a dedicated signing key. Never use the Android
debug key or commit signing material, passwords, aliases, or `key.properties`.

## Compartilhamento CSV em desenvolvimento

Configurações oferece exportação local por share_plus. Após adicionar ou
atualizar o plugin, pare a execução e rode `flutter run` para recompilar e
instalar a parte nativa; hot reload/hot restart não bastam. Não desinstale o app
nem limpe seus dados para resolver ausência do plugin.

O manifest da biblioteca fornece ShareFileProvider, com a autoridade
`com.bed.cordato.flutter.share_provider`. Não duplique esse provider no manifest
principal nem adicione permissões amplas de arquivos ou rede para exportar CSV.
Na investigação de 24/11/2026, o pacote instalado no dispositivo não continha esse
provider; a falha não comprova problema no CSV ou na origem fixa usada no iPad.
Compartilhamento real, destinos escolhidos e comportamento distribuído ainda
exigem homologação em aparelho com a instalação atualizada.

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
| `failure_` | Validation failures | `failure_expense_invalid_amount` |
| `success_` | Successful operation feedback | `success_expense_saved` |
| `label_` | UI names, titles, labels and descriptions | `label_home_widget_name` |
| `action_` | Buttons and other action text | `action_home_widget_add_expense` |
| `cd_` | Accessibility descriptions | `cd_home_widget_monthly_summary` |
| `msg_` | General messages, hints, toasts and snackbars | `msg_home_widget_update_required` |
| `config_` | Technical configuration, not user-facing text | `config_home_widget_update_interval` |

Current contexts are `app`, `common` and `home_widget`. Use
`common` only for truly shared text, not as a catch-all. Keep technical values,
invariant brand names, currency symbols and symbol-only actions explicitly
non-translatable. Preserve numbered format
arguments such as `%1$s` and `%2$s` when renaming or translating resources.
Accessibility descriptions have their own `cd_` resources rather than borrowing
a UI label. New prefixes or contexts require updating this convention and its
architecture tests; do not create empty files or placeholder strings for unused
message types. Resources in localized `values-*` directories retain the same
names and context filenames as their default counterparts.

`test/architecture/android_string_resources_test.dart` checks naming, context
separation, duplicate declarations, non-translatable technical values and native
references. Local runtime tests reject legacy microphone and authentication declarations.

Historical verification before the local transition: `flutter pub get` succeeded,
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
as well, the action becomes a square **+** button with 8dp corners and a centered
vector icon in the same colors, reserving
32dp plus 12dp spacing beside the summary. Other sizes keep **+ Nova despesa**. The
whole widget remains tappable to open New expense, with its accessible description.
Horizontal padding stays at 16dp even in a single row; vertical padding alone
shrinks to 4dp. Narrow single-row money beside the compact action starts at 15; wide single-row
money retains 16. Vertical layouts use 19, capped at 21 for accessibility, while
regular horizontal layouts retain 22, capped at 26. Money can shrink further to
keep all digits inside the padded summary rather than pressing against the edges.
There are no background HTTP requests. A local inexact alarm
and date/time-zone broadcasts re-render month changes, subject to OS scheduling.
Install a fresh
build and add **Adicionar despesa** from the launcher's widget picker. Its single
tap action is delivered through `home_widget`, not Flutter's automatic deep-link
handler. `MainActivity` disables automatic deep linking only for that plugin
action. Authentication app-link declarations and their association generator were removed.

Flutter coordination now uses `WidgetLaunchBloc`, `WidgetSyncBloc`,
`WidgetLaunchRepository` and `WidgetSyncRepository`, with `widget_*` files.
The plugin name, `homeWidget=true` URI parameter, Kotlin classes and Android
resource names are unchanged. Flutter tests mirror these renamed types; native
tests keep their JUnit layout under `android/app/src/test`.

Before release, manually verify cold/warm launches directly into Dashboard,
creation form deduplication with unsaved input, editing versus creation,
return to Dashboard after saving/back, and system light/dark themes.
Also verify current-month totals while Dashboard uses a historical filter, a
successful empty month, storage/publication failures retaining the last valid
summary, and month rollover showing **Abra para atualizar** until a new sync.
Totals come from local Metrics, without login, logout or background HTTP.
User/Expense/Metrics share the Drift DatabaseClient. Expense refresh requests
follow successful writes/commit, and WidgetSyncRepository queries the current
monthly summary through MetricsRepository/MetricsDao. The native snapshot format,
App Group and URI contract have not changed. Native policy tests do not validate
Dart persistence, migrations, local-time defaults, power-failure durability or recovery.
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

Build the local application without server configuration:

```bash
flutter build apk --release
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

Flutter 3.50.0 scans dependency build scripts using regex and still warns about
`home_widget` because the inactive conditional branch contains `apply plugin:
'kotlin-android'`. Runtime inspection confirmed that neither `kotlin-android`
nor `org.jetbrains.kotlin.android` is applied to that subproject with built-in
Kotlin enabled. Eliminating that remaining false positive requires an upstream
tooling/package fix; do not hide it by disabling dependency validation or editing
the pub cache.

Historical result before the local transition: after the Flutter 3.50 upgrade,
Android unit tests and the release APK build
passed with the current AGP 9.5.1 and Gradle 9.6.0 configuration. The legacy DSL
deprecation and the known `home_widget` KGP warning remain; no validation was
disabled. Keep `android.newDsl=false` until plugin compatibility is verified.
The GitHub workflow itself and release-mode widget/app-link behavior on a
device still require validation.

Messages about engine flags passed via Intent are emitted by Flutter's Android
embedding during CLI debug launches. Impeller, viewport and VM Service messages
are normal debug diagnostics, not application build failures.

### Distribution Artifacts

The last documented Google Play internal-testing version was **1.0.0 (5)**.
This is not a current Play Console query. Before generating a local Android
App Bundle, check the highest code already used and coordinate it with the
workflow counter. For example, only if code 6 is still unused:

```bash
flutter build appbundle --release \
  --build-name=1.0.0 \
  --build-number=6
```

Use a higher build number for subsequent uploads, coordinating local codes with
the workflow below. After uploading manually to internal testing, install or
update through the tester's Google Play link, confirm the expected version code,
and verify the local profile, manual expenses and native widget. Local release success does not by
itself validate the artifact distributed by Play.

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

Inspect permissions in the merged release manifest:

```bash
grep -F 'android.permission.INTERNET' \
  build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml
```

The main manifest does not declare network or microphone permissions.
Inspect the final merged manifest because dependencies may contribute declarations.
The exact merged-manifest directory is Android Gradle Plugin-version specific;
use the generated `build/app/intermediates/` path if this location changes.

### GitHub Actions: AAB assinado sob demanda

O workflow [Android release](../.github/workflows/android-release.yml) roda
somente por `workflow_dispatch`, na branch `main`. Não publica no Google Play,
não cria releases/tags/commits e não altera o `pubspec.yaml`. O token do workflow
tem somente `contents: read`; o checkout não persiste suas credenciais Git.

#### Configuração única

1. Criar o environment **android-release** em Settings → Environments do
   repositório e restringir deployments à branch `main`. Configurar aprovação
   manual se disponível no plano do GitHub.
2. Cadastrar os quatro environment secrets abaixo. Usar a **mesma chave de upload
   aceita pelo app existente** no Google Play, não uma chave debug ou uma nova
   chave gerada apenas para o CI. Com Play App Signing, a chave de upload pode ser
   diferente da chave com que o Google assina o aplicativo distribuído.

| Secret | Conteúdo |
| --- | --- |
| `ANDROID_RELEASE_KEYSTORE_BASE64` | Arquivo de keystore existente codificado em base64. |
| `ANDROID_RELEASE_STORE_PASSWORD` | Senha do keystore. |
| `ANDROID_RELEASE_KEY_ALIAS` | Alias da chave de upload. |
| `ANDROID_RELEASE_KEY_PASSWORD` | Senha da chave. |

3. **Passo legado ainda no YAML:** `LOCALSTORE_READ_TOKEN` foi preparado como PAT
   de leitura somente de Contents em `bed72/localstore`. O workflow ainda falha
   antes de resolver dependências se o secret estiver ausente. Drift não precisa
   desse token; revisar a remoção do passo é tarefa de código separada. Esta
   documentação não solicita cadastrar credencial obsoleta nem confirma secrets
   remotos. Em revisões históricas, GITHUB_TOKEN não concedia acesso ao fork privado.

O token de leitura é recebido somente no passo de dependências e fornecido ao
Git por helper em variável de ambiente, limitado à URL do fork. Não é gravado
em arquivo, URL do pubspec, cache de credenciais ou log. A configuração usa
`credential.useHttpPath`; não habilite debug de shell ou dumps do ambiente.
Os passos posteriores usam `--no-pub`, sem acesso ao token.

No macOS, é possível copiar a codificação diretamente para o clipboard, sem
imprimi-la no terminal, e colá-la no secret:

```bash
base64 -i /caminho/seguro/cordato-release.jks | pbcopy
```

Base64 não é criptografia: não salvar esse conteúdo em arquivos versionados,
logs, issues ou mensagens. Limpar o clipboard depois de cadastrar o secret.
Não é necessário cadastrar conta de serviço Google, JSON ou credenciais do Play.

#### Execução e download

Somente após resolver os bloqueios de Metrics e revisar o passo legado, abrir
Actions → **Android release** →
**Run workflow**, selecionar `main` e executar. Outras branches são ignoradas.
O job usa Ubuntu 24.04, Java 21, Android SDK 37 (pacote
`platforms;android-37.0`), Build Tools 37.0.0 e Flutter **3.50.0 stable**.
O YAML atual instala dependências com o lockfile obrigatório e ainda exige o
secret legado de leitura do fork,
executa `flutter analyze --no-pub` e a suíte Flutter unitária completa com
`--no-pub` antes de acessar os secrets de assinatura.

O Gradle recebe os valores de assinatura por variáveis de ambiente, usando sua
validação existente sem fallback para debug. O keystore fica em `runner.temp`,
com permissões restritas, e um passo `always()` remove o arquivo após o job.
Não se deve habilitar debug de shell ou adicionar dumps do ambiente aos passos.

O workflow não injeta configuração de backend. Após o build, verifica a
presença da assinatura e executa `jarsigner -verify`. O único arquivo enviado é
`build/app/outputs/bundle/release/app-release.aab`, em um artefato
`cordato-<versão>-<código>-attempt-<tentativa>`, retido por **14 dias**. Baixar pelo
resumo ou pela área Artifacts da execução, extrair o AAB e enviá-lo manualmente
ao Google Play Console. O AAB não é um APK instalável diretamente.

#### Versão e código do build

[`tool/android_release_version.sh`](../tool/android_release_version.sh) lê a
versão visível do `pubspec.yaml` e calcula `GITHUB_RUN_NUMBER + 5`. A primeira
execução deste workflow gera código **6**, acima do **5** em teste interno.
O build usa `--build-name` e `--build-number`; não grava esses valores no projeto.

| `pubspec.yaml` | Execução | Artefato |
| --- | --- | --- |
| `version: 1.0.0+1` | 1 | `1.0.0 (6)` |
| `version: 1.0.1+1` | 2 | `1.0.1 (7)` |
| `version: 1.1.0+1` | 3 | `1.1.0 (8)` |

Para mudar a versão visível, alterar somente `1.0.0` para `1.0.1` ou `1.1.0` no
`pubspec.yaml`, integrar a alteração à `main` e disparar outra execução. O sufixo
local `+1` não determina o código no CI. A sequência não reinicia quando a versão
visível muda; execuções que falham também consomem números, portanto lacunas são
esperadas e aceitas pelo Google Play.

**Re-run jobs mantém o mesmo código** da execução original. Serve para repetir
uma tentativa que falhou, não para gerar uma atualização após publicar aquele
código. Para um novo código, usar **Run workflow** novamente. O número da
tentativa diferencia os artefatos de uma reexecução.

O contador pertence a este workflow, não ao Google Play. Não recriar/renomear o
arquivo de workflow nem gerar uploads locais independentes sem revisar o offset
`+ 5` para superar o maior código já utilizado. Enviar artefatos em ordem crescente;
um código menor que outro já enviado não pode ser reutilizado. O workflow não
consulta a versão publicada nem configura os secrets automaticamente.

As actions estão fixadas por SHA: checkout 7.0.1, setup-java 6.2.0, setup-android
4.0.4, flutter-action 2.23.0 e upload-artifact 7.0.2. Atualizar os SHAs e esta lista
juntos após revisão. A primeira execução remota assinada continua dependendo da
configuração dos secrets e não é comprovada pela validação local do YAML/testes.

Verificação histórica da entrega do workflow, anterior à transição local:
`actionlint .github/workflows/android-release.yml`,
`shellcheck tool/android_release_version.sh`, `flutter pub get --enforce-lockfile`
e `flutter analyze` passaram; `flutter test --reporter failures-only` aprovou
**1420 testes**, incluindo os cenários de versionamento, mudança de versão visível,
reexecução, entradas inválidas e limite de código. Não houve build assinado local,
execução da Action, acesso ao keystore ou publicação remota nesta verificação.

### Historical Focus And Splash Verification

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

## Links do widget

O atalho do widget usa `home_widget` e a URI `cordato://widget/add-expense?homeWidget=true`.
Não há app links de autenticação, associated domains no iOS ou gerador de
associações. O scheme `cordato` e o App Group foram preservados no iOS.

## Key Rotation

Keep the release keystore in the approved secret store and restrict access to
authorized maintainers. When rotating a key, replace the keystore and all four
local or environment values together, build a new artifact, and verify its
certificate before distribution. Android signing keys may be constrained by the
distribution channel, including Google Play App Signing; coordinate any key
replacement with that channel before publishing.
