# settings-screen-ui Specification

## Purpose
TBD - created by syncing change create-settings-screen-ui.

## Requirements

### Requirement: Settings screen structure
The settings presentation SHALL render an app bar, a header, a scrollable settings area, and a logout action in that visual order.

#### Scenario: Rendering the complete screen
- **WHEN** `SettingsScreen` is rendered
- **THEN** it shows the title “Configurações” and description “Gerencie suas preferências.”
- **THEN** it shows the sections “Casal”, “Conta”, and “Informações” in that order
- **THEN** it shows the logout action after the settings area

#### Scenario: Rendering on constrained height
- **WHEN** the available height cannot display every settings option at once
- **THEN** the settings area can be vertically scrolled without overflowing the screen
- **THEN** the layout remains inside the device safe area

### Requirement: Settings app bar
The settings presentation SHALL provide a feature-specific app bar that reuses the shared back button and delegates navigation through an optional callback.

#### Scenario: Back action is available
- **WHEN** the user activates the back button and `onBackPressed` is provided
- **THEN** the callback is invoked exactly once

#### Scenario: Back action is unavailable
- **WHEN** `onBackPressed` is not provided
- **THEN** the back action is rendered disabled and no navigation is attempted

### Requirement: Couple invitation section
The “Casal” section SHALL contain a settings invitation widget with a person-add icon, the title “Convidar parceiro”, the description “Comecem a usar juntos”, and a trailing chevron.

#### Scenario: Partner invitation is available
- **WHEN** the user activates the invitation and `onInvitePartnerPressed` is provided
- **THEN** the callback is invoked exactly once

#### Scenario: Couple state remains out of scope
- **WHEN** the settings screen is rendered
- **THEN** it does not load, infer, or display connected-couple, loading, or failure states

### Requirement: Account settings section
The “Conta” section SHALL group the “Dados pessoais” and “Subscrição” items in one settings card, preserving that order and showing a “PREMIUM” badge on “Subscrição”.

#### Scenario: Account action is available
- **WHEN** the user activates an account item whose callback is provided
- **THEN** the corresponding callback is invoked exactly once

#### Scenario: Premium account item
- **WHEN** the “Subscrição” item is rendered
- **THEN** it displays the premium badge before its trailing chevron

### Requirement: Information settings section
The “Informações” section SHALL group the “Termos de uso”, “Políticas de privacidade”, and “Ajuda” items in one settings card in that order.

#### Scenario: Information action is available
- **WHEN** the user activates an information item whose callback is provided
- **THEN** the corresponding callback is invoked exactly once

#### Scenario: Information action is unavailable
- **WHEN** an information item has no callback
- **THEN** the item is disabled and does not execute a placeholder action

### Requirement: Grouped settings card
The settings card SHALL render its children in a themed container with horizontal item padding and a divider only between adjacent items.

#### Scenario: Card contains multiple items
- **WHEN** a settings card receives more than one child
- **THEN** every child is rendered in the supplied order
- **THEN** exactly one divider is rendered between each adjacent pair and no divider is rendered after the final child

### Requirement: Settings item interaction
Each settings item SHALL show a leading icon, a single-line ellipsized label, optional premium badge, and trailing chevron, and SHALL reuse the shared press-bounce behavior when enabled.

#### Scenario: Long item label
- **WHEN** a settings item label exceeds the available width
- **THEN** the label remains on one line and is truncated with an ellipsis without displacing trailing content

#### Scenario: Disabled item
- **WHEN** a settings item receives no callback
- **THEN** its press interaction is disabled

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
- **THEN** no module, session state, repository, command, or external service is initialized
