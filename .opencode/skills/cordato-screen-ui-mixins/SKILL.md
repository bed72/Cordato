---
name: cordato-screen-ui-mixins
description: Use when creating, reviewing, or refactoring Cordato StatefulWidget screens with substantial local UI state, lifecycle, controllers, listeners, timers, or interaction handlers.
---

# Cordato Screen UI Mixins

Use this skill to keep complex screen composition declarative while preserving
local UI state in the presentation layer.

## When To Extract

Create a mixin only when a `StatefulWidget` has enough local UI state, lifecycle
work, and handlers that its `build` becomes difficult to read. Typical contents
are controllers, timers, command listeners, field validation, local loading,
toast feedback, submission handlers, and `initState`/`dispose`.

Do not create a mixin for a few simple fields or merely to split layout code.
Do not use this pattern with `StatelessWidget`; keep its pure visual logic in
composition or private methods instead.

## Implementation

1. Put the mixin in `presentation/mixins/<screen>_state_mixin.dart`.
2. Name it `<Screen>StateMixin` and constrain it with `on State<Screen>`.
3. Expose only the state and handlers the screen needs to compose widgets.
4. Override `initState` and `dispose` in the mixin when it owns listeners or
   resources; remove listeners and dispose every owned resource.
5. Apply it only to the owning screen state with `with <Screen>StateMixin`.
6. Keep the screen `build` focused on widget composition.

## Boundaries

- The mixin belongs to the feature's presentation layer and is screen-specific.
- It may use `BuildContext`, presentation extensions, and presentation commands.
- It must not access Supabase, storage, SDK clients, data sources, repositories,
  or domain business rules directly.
- Do not make a generic mixin for unrelated screens. Extract a shared component
  only after concrete reuse is established.

## Verification

Run:

```bash
dart format lib/features/<feature>/presentation
flutter analyze
flutter test
```
