## MODIFIED Requirements

### Requirement: Logout presentation
The settings presentation SHALL render a full-width “Sair” action using the shared danger button, SHALL require confirmation in a bottom sheet, and SHALL execute the injected logout command only after confirmation.

#### Scenario: Opening logout confirmation
- **WHEN** the user activates the settings “Sair” action while the logout command is idle
- **THEN** the settings presentation opens a dismissible bottom sheet
- **THEN** the logout command is not executed at that time
- **THEN** the bottom sheet shows the title “Deseja sair?” and description “Você precisará entrar novamente para acessar sua conta.”
- **THEN** the bottom sheet applies safe-area inset only at the bottom of its confirmation content
- **THEN** the bottom sheet shows a full-width outline action labeled “Voltar” followed by a full-width elevated action labeled “Sair”

#### Scenario: Confirming logout
- **WHEN** the logout confirmation bottom sheet is open and the user activates “Sair”
- **THEN** the bottom sheet is closed
- **THEN** the logout command is executed exactly once after confirmation
- **THEN** the settings presentation does not directly terminate the session or navigate

#### Scenario: Logout is running
- **WHEN** the logout command is executing
- **THEN** the settings “Sair” action displays its loading state
- **THEN** the action is disabled
- **THEN** another confirmation or logout execution cannot be started

#### Scenario: Logout fails
- **WHEN** the logout command exposes `LogoutFailure`
- **THEN** Settings shows an error toast titled “Não foi possível sair” with the localized failure message
- **THEN** the settings “Sair” action returns to its enabled state
- **THEN** the user can start another confirmation attempt

#### Scenario: Returning from logout confirmation
- **WHEN** the logout confirmation bottom sheet is open and the user activates “Voltar”
- **THEN** the bottom sheet is closed
- **THEN** the logout command is not executed

#### Scenario: Dismissing logout confirmation
- **WHEN** the logout confirmation is dismissed by dragging, tapping outside, or using the system back action
- **THEN** the logout command is not executed

### Requirement: Cordato presentation conventions
All new settings screen and widget code MUST use `material_ui`, existing Cordato theme accessors, shared interaction components, `command_it` for the asynchronous logout operation, and the Authentication domain contract without accessing external SDKs or adapters.

#### Scenario: Implementing the settings UI
- **WHEN** the settings files are created or updated
- **THEN** widgets are public `final` classes with matching filenames and `Widget` suffixes
- **THEN** colors, typography, and radii are derived from the active Cordato theme
- **THEN** `LogoutCommand` depends on `IAuthenticationRepository` and converts `Left` into an observable command error
- **THEN** the screen mixin removes every command listener it creates
- **THEN** no Settings screen, mixin, or widget imports Authentication data or infrastructure, storage, Supabase, or a global router

### Requirement: Settings preview
The Cordato settings previews SHALL render the completed screen with a disposable logout command backed by a local fake repository and SHALL provide direct visual inspection of the logout confirmation using the real application theme wrapper.

#### Scenario: Opening the settings screen preview
- **WHEN** the settings screen preview is loaded in Flutter Widget Previewer
- **THEN** the complete hierarchy and enabled logout state can be inspected without initializing modules, routing, session state, or external services
- **THEN** the preview-created logout command is disposed with the preview lifecycle

#### Scenario: Opening the logout confirmation preview
- **WHEN** the logout confirmation preview is loaded in Flutter Widget Previewer
- **THEN** the bottom sheet scaffold, title, description, bottom safe area, return action, and elevated logout action can be inspected together using the real application theme
- **THEN** no module, session state, repository implementation, command, or external service is initialized
