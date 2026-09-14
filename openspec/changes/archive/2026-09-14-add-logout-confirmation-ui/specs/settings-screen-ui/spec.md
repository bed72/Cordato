## MODIFIED Requirements

### Requirement: Logout presentation
The settings presentation SHALL render a full-width “Sair” action using the shared danger button and SHALL require confirmation in a bottom sheet before delegating the optional logout callback.

#### Scenario: Opening logout confirmation
- **WHEN** the user activates the settings “Sair” action and `onLogoutPressed` is provided
- **THEN** the settings presentation opens a dismissible bottom sheet
- **THEN** the callback is not invoked at that time
- **THEN** the bottom sheet shows the title “Deseja sair?” and description “Você precisará entrar novamente para acessar sua conta.”
- **THEN** the bottom sheet applies safe-area inset only at the bottom of its confirmation content
- **THEN** the bottom sheet shows a full-width outline action labeled “Voltar” followed by a full-width elevated action labeled “Sair”

#### Scenario: Confirming logout
- **WHEN** the logout confirmation bottom sheet is open and the user activates “Sair”
- **THEN** the bottom sheet is closed
- **THEN** `onLogoutPressed` is invoked exactly once after confirmation
- **THEN** the settings presentation does not directly terminate the session or navigate

#### Scenario: Returning from logout confirmation
- **WHEN** the logout confirmation bottom sheet is open and the user activates “Voltar”
- **THEN** the bottom sheet is closed
- **THEN** `onLogoutPressed` is not invoked

#### Scenario: Dismissing logout confirmation
- **WHEN** the logout confirmation is dismissed by dragging, tapping outside, or using the system back action
- **THEN** `onLogoutPressed` is not invoked

#### Scenario: Logout action is unavailable
- **WHEN** `onLogoutPressed` is not provided
- **THEN** the settings “Sair” action is disabled
- **THEN** the confirmation bottom sheet cannot be opened from that action

### Requirement: Settings preview
The Cordato settings previews SHALL render the completed screen with representative enabled callbacks and SHALL provide direct visual inspection of the logout confirmation using the real application theme wrapper.

#### Scenario: Opening the settings screen preview
- **WHEN** the settings screen preview is loaded in Flutter Widget Previewer
- **THEN** the complete hierarchy and enabled visual states can be inspected without initializing modules, routing, session state, or external services
- **THEN** activating the enabled “Sair” action opens the logout confirmation

#### Scenario: Opening the logout confirmation preview
- **WHEN** the logout confirmation preview is loaded in Flutter Widget Previewer
- **THEN** the bottom sheet scaffold, title, description, bottom safe area, return action, and elevated logout action can be inspected together using the real application theme
- **THEN** no module, session state, repository, command, or external service is initialized
