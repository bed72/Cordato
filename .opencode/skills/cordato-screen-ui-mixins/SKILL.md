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
toast feedback, submission handlers, and owned `initState`/`dispose` resources.
Async execution state belongs in Bloc, never mirrored in local flags.

Do not create a mixin for a few simple fields or merely to split layout code.
Pure visual StatelessWidget logic may use a dedicated mixin constrained with
`on StatelessWidget`, without mutable resources or asynchronous operations.

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
- It may use BuildContext, presentation extensions, Bloc events and states;
  do not introduce presentation commands.
- It must not access HTTP, storage, SDK clients, data sources, repositories,
  or domain business rules directly.
- Do not make a generic mixin for unrelated screens. Extract a shared component
  only after concrete reuse is established.

## Bloc Ownership And Routes

- New or explicitly migrated page state uses Modular route `provide` and the
  core `BlocScopedExtension.addBloc`. Only Sign-in is currently migrated.
  Its screen/mixin receives an instance and never creates or closes it.
- Remaining screens still create/replace/close stable Bloc factories. Session
  stays global under AppWidget. Never mix ownership models on one instance.
- Dispose only resources the mixin creates: controllers, listeners and timers.
  External Bloc ownership does not remove cleanup of local resources.
- Use the State's own context for navigation, without redundant context arguments
  or navigation callbacks in route arguments. Preserve post-await mounted,
  Bloc identity and stale-result checks. ExpensesScreen navigates to editing
  directly and applies only a confirmed ExpenseEntity result.
- Dashboard/Metrics refresh when returning from the expense list, including an
  unchanged list. Do not add a local mutation flag or intercept native back just
  to report changes to the parent.
- Do not add code comments; document decisions in Markdown. Do not extract
  private visual widgets into screen files.

## Verification

Run:

```bash
dart format lib/features/<feature>/presentation
flutter analyze
flutter test
```
