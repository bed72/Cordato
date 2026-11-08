# expense-csv-export Specification

## Purpose

Define the authenticated user's complete own-expense CSV export from Settings, including Brazilian spreadsheet formatting, privacy, native sharing, route lifecycle, and safe temporary-file handling.

## Requirements

### Requirement: Export entry point in Settings

Settings SHALL offer “Exportar despesas” in its Conta section for the authenticated user, preserving existing actions. Export SHALL require internet and the Settings route to remain active during preparation. It MUST NOT offer period/category selection, a save-location picker, or background execution.

#### Scenario: Starting export
- **WHEN** the user activates “Exportar despesas”
- **THEN** preparation starts without asking for filters or a destination folder
- **AND** Settings displays “Preparando exportação…”

### Requirement: Complete own-expense history

Export SHALL read all pages of the authenticated user's expenses through the existing PocketBase API, independently of loaded screens and their filters. Every page MUST explicitly filter the owner captured at the start using SDK filter escaping. Backend authorization remains authoritative; the client filter is not an authorization guarantee. Export MUST NOT include family members' expenses, profile data, tokens, or credentials.

#### Scenario: History spans several pages
- **WHEN** the user has expenses across several API pages and dates
- **THEN** export reads every page to completion, with the same owner filter and deterministic ordering
- **AND** the file includes the complete returned history, not only currently displayed expenses

#### Scenario: Family expenses are readable
- **WHEN** the account can read another family member's expenses
- **THEN** the export query still restricts records to the exporting user's owner ID
- **AND** no combined-family query is used

#### Scenario: Identity becomes unavailable or changes
- **WHEN** authenticated identity is absent at the start or changes before preparation finishes or sharing is requested
- **THEN** export does not continue under a different identity or open a new share sheet with the previous account's file
- **AND** no export operation clears or refreshes the AuthStore

### Requirement: Brazilian spreadsheet CSV format

The file SHALL contain the header `Identificador;Data;Descrição;Categoria;Valor (BRL)` in that order, followed by one record per expense. It SHALL use UTF-8 with BOM, semicolon separators, CRLF record endings, and the `.csv` extension with MIME type `text/csv`. The filename SHALL identify Cordato expenses and the export date without including personal information. Identificador SHALL be the expense ID; Categoria SHALL be the stable category enum value. Data SHALL use `dd/MM/yyyy`, preserving the expense's civil date without timezone conversion. Valor (BRL) SHALL use comma decimals and exactly two fractional digits, without currency symbol or thousands separators, calculated from integer cents without `double`.

#### Scenario: Exact monetary and date serialization
- **WHEN** an expense has 123456 cents, category `food`, and civil date 2026-11-08
- **THEN** its value is `1234,56`, its category is `food`, and its date is `08/11/2026`
- **AND** zero cents is serialized as `0,00` and one cent as `0,01`

#### Scenario: Special characters
- **WHEN** a description contains accents, semicolons, quotes, or line breaks
- **THEN** accents remain intact and CSV escaping preserves those characters inside a single field
- **AND** embedded quotes are escaped without adding extra expense records

### Requirement: Spreadsheet formula protection

Export SHALL treat textual cells as untrusted input. Before CSV encoding, it MUST prefix an apostrophe to textual values beginning with `=`, `+`, `-`, or `@`, including when preceded by whitespace/control characters, and values beginning with tab, CR, or LF. This transformation SHALL affect only the exported representation, not stored expenses or numeric/date formatting. Quoting alone MUST NOT be treated as formula protection.

#### Scenario: Description could be evaluated as a formula
- **WHEN** a description begins with `=SUM(A1:A2)` or whitespace followed by a formula marker
- **THEN** the exported textual cell has a leading apostrophe and is CSV-escaped normally
- **AND** the original stored description remains unchanged

### Requirement: Native sharing of the generated file

After successful nonempty preparation, the active Settings presentation SHALL request the Android/iOS native share sheet exactly once with the CSV attachment. File generation SHALL happen on the device; no export endpoint or server-side file SHALL be created. Available destinations depend on the OS and installed applications. The app MUST NOT equate opening or completing the share sheet with durable saving or delivery to a destination.

#### Scenario: Sharing a completed export
- **WHEN** every page was read successfully and a valid nonempty CSV was prepared while Settings remains active
- **THEN** the native share sheet opens with the named CSV attachment
- **AND** the app does not open a save-location picker

#### Scenario: User dismisses sharing
- **WHEN** the user dismisses the share sheet or the platform cannot report the chosen action
- **THEN** Settings becomes available for a new export
- **AND** dismissal or an unavailable outcome is not shown as an export failure or a confirmed delivery

### Requirement: Empty history and failure behavior

For empty history, Settings SHALL show “Você ainda não tem despesas para exportar”, without generating or sharing an empty/header-only file. Any failed page, invalid record, encoding failure, temporary-file failure, or native sharing failure SHALL prevent a partial file from being offered as a successful export. Expected failures SHALL preserve application error metadata and display safe local Portuguese feedback with manual retry. Unexpected failures MUST remain observable through the standard Bloc error mechanism without recording financial payloads.

#### Scenario: No expenses
- **WHEN** the history query completes with no expenses
- **THEN** Settings shows “Você ainda não tem despesas para exportar”
- **AND** no CSV file or share sheet is created

#### Scenario: A later page fails
- **WHEN** initial pages succeed and a subsequent page fails
- **THEN** the native share sheet does not open and no partial CSV is offered
- **AND** Settings reports the failure and permits retry from the first page

#### Scenario: Internet is unavailable
- **WHEN** the history request fails due to connectivity
- **THEN** Settings shows safe local failure feedback and permits manual retry
- **AND** no automatic retry or offline-completeness claim occurs

### Requirement: Concurrency and route lifecycle

A route-owned export Bloc SHALL control preparation and share execution, discarding duplicate submissions while either phase is pending. After empty history, failure, or share completion/dismissal, a new manual export SHALL be allowed. Navigation/disposal before share dispatch MUST prevent opening a late share sheet. Bloc closure MUST NOT be represented as cancellation of requests already in flight or removal of files already sent to other apps.

#### Scenario: Repeated activation
- **WHEN** export is preparing or its native sharing operation is pending
- **THEN** subsequent export activations start no additional query, file, or share operation

#### Scenario: Settings is closed during preparation
- **WHEN** the route is disposed before the pending preparation completes
- **THEN** no late state, toast, or share sheet is emitted for that route
- **AND** resources produced by the abandoned operation follow the temporary-file cleanup policy

### Requirement: Sensitive temporary-file handling

Generated files SHALL use an app-owned temporary directory, never a public destination chosen implicitly by the app. The implementation SHALL define and test cleanup of failed/abandoned files and stale export files, without deleting unrelated cache content or revoking access while a receiving app may still read an attachment. Logs and telemetry MUST NOT contain CSV contents, expense descriptions, credentials, or attachment paths. Export SHALL request no broad device-storage permission.

#### Scenario: Failed preparation leaves a temporary artifact
- **WHEN** preparation fails after creating a partial temporary artifact
- **THEN** that artifact is discarded and never shared

#### Scenario: Old exports remain in cache
- **WHEN** stale export cleanup runs
- **THEN** only files owned by this export feature and outside its active retention window are removed
- **AND** unrelated cache entries and active attachments are preserved
