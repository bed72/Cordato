# Spec Delta

## MODIFIED Requirements

### Requirement: Export entry point in Settings

Settings SHALL offer “Exportar despesas” in its Dados section for the local profile, preserving existing actions. Export SHALL work without internet and require the Settings route to remain active during preparation. It MUST NOT offer period/category selection, a save-location picker, or background execution.

#### Scenario: Starting export
- **WHEN** the user activates “Exportar despesas”
- **THEN** preparation starts without asking for filters or a destination folder
- **AND** Settings displays “Preparando exportação…”

### Requirement: Complete own-expense history

Export SHALL read the complete local expense history independently of loaded screens and their filters, in deterministic civil-date and ID order. It MUST NOT require authenticated identity or include profile data, tokens or credentials. The document SHALL contain only expense data, with no owner identity.

#### Scenario: History spans several pages
- **WHEN** local history exceeds the normal list page size
- **THEN** the file includes all returned local expenses, not only currently displayed expenses

#### Scenario: Offline local profile
- **WHEN** no remote identity or internet connection exists
- **THEN** local expenses can still be exported

#### Scenario: Family expenses are readable
- **WHEN** external services could expose another person's history
- **THEN** export still reads only the device's local expenses, without any remote or combined-family query

#### Scenario: Identity becomes unavailable or changes
- **WHEN** remote identity is unavailable or changes outside the local application
- **THEN** preparation and sharing of the local CSV do not consult or depend on that identity

### Requirement: Empty history and failure behavior

For empty history, Settings SHALL show “Você ainda não tem despesas para exportar”, without generating or sharing a header-only file. Failed storage reads, invalid records, encoding failures, temporary-file failures and native sharing failures SHALL prevent partial success. Expected errors SHALL retain metadata with safe Portuguese feedback and manual retry. Unexpected errors MUST remain observable through Bloc without financial payloads.

#### Scenario: No expenses
- **WHEN** the history query completes with no expenses
- **THEN** Settings shows “Você ainda não tem despesas para exportar”
- **AND** no CSV file or share sheet is created

#### Scenario: Invalid local history
- **WHEN** a storage read or a record conversion fails during preparation
- **THEN** no partial CSV is offered and manual retry remains available

#### Scenario: A later page fails
- **WHEN** initial local history batches succeed and a later storage batch fails
- **THEN** no partial file or native share request is offered
- **AND** manual retry starts from the first local batch

#### Scenario: Internet is unavailable
- **WHEN** internet is unavailable but local history is readable
- **THEN** preparation succeeds without a network request
