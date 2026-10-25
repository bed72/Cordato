---
name: cordato-architecture
description: Use ONLY when creating, reviewing, or changing Cordato features, modules, repositories, routes, or bounded-context boundaries; enforce the validated financial domain and Flutter layering.
---

# Cordato Architecture

Use this skill for architecture-sensitive work in the Cordato Flutter app.

## Source Of Truth

Review these sources before changing architecture or a financial feature:

1. Project rules and the validated product model.
2. Architecture guidance for Flutter layers, modules, routes, and dependency rules.
3. Product scope and current implementation status.
4. The affected feature files and their tests.

The Kotlin backend at `/Users/gabrielramos/Code/Me/BackEnd/Kotlin/Cordato` is a
domain reference only. Do not copy its package structure into Flutter.

## Product Boundaries

- `expense` owns individual spending facts.
- `budget` owns individual planned ceilings by inclusive date range.
- `family` is a read-only lens over its members and owns no financial data.
- `insight` is a read-only projection with no persistence of its own.
- `authentication` owns email/password sign-in, sign-up, email confirmation,
  resend and logout over HTTP. `session` independently observes token presence
  in storage; neither context imports the other.
- `user` owns profile data; `metrics` owns read-only financial aggregates.
- `dashboard` is presentation/composition, not a business bounded context.
- `chat` is out of scope and must not be introduced without an explicit product decision.

Preserve these invariants:

- money is positive integer cents in BRL;
- expenses never reference budgets; budget membership is derived from dates;
- live budgets of one person cannot overlap;
- family membership never grants write access to another member's data;
- leaving or ending a family does not alter individual data;
- family views and insights are recomputed and not persisted as source data.

## Dependency Rules

- Follow `Screen -> Bloc -> application repository contract`, implemented by
  infrastructure repositories using shared core client interfaces.
- Contracts belong in application and return `Future<T>` with typed application
  exceptions. Do not introduce Either, commands, use cases or data sources to
  wrap simple delegation. DTO parsing belongs in infrastructure.
- Domain is pure. Keep HTTP, storage, SDKs and concrete repositories out of
  application/presentation; domain also must not import application.
- `expense` and `budget` do not import sibling business contexts.
- `family` may read `budget` and `expense` only through its own contracts, with concrete adapters at the infrastructure edge.
- `insight` may read `budget`, `expense`, and `family` only through its own contracts, with concrete adapters at the infrastructure edge.
- Owner contexts must never depend on `family` or `insight`.
- Do not add direct imports of another context's implementation to bypass its contract.

## Workflow

1. Identify the owning bounded context before creating a file.
2. Keep domain rules and contracts framework-free.
3. Put HTTP payloads, parsing and client exception translation in infrastructure.
4. Add or update the architecture test for any new dependency direction.
5. Add behavior tests in the affected layer.
6. Run `flutter analyze` and `flutter test` before finishing.

When a proposed change conflicts with these boundaries, stop and ask for a
product or architecture decision instead of weakening the rule silently.

## Modular V7, Ownership And Navigation

- For new or explicitly migrated page state, use route `provide` with
  `scope.addBloc<MyBloc>(MyBloc.new)`, importing the existing core
  `BlocScopedExtension`. It preserves injected constructor tear-offs and adapts
  stream/close to `addStreamable`.
- Modular owns that instance; pass `context.read<MyBloc>()` to the screen and
  retain explicit BlocBuilder/BlocConsumer and listeners. Do not also bind the
  Bloc in the module, close it in the screen or create a second owning provider.
- Only Sign-in currently uses page-scoped ownership. Other screens retain stable
  factories and their own lifecycle until explicitly migrated. Session remains
  globally owned by AppWidget. Previews/tests must honor the same ownership.
- Path-less modules provide root-owned shared dependencies; feature binds with
  a path only exist while the feature is active. Test cross-feature DI without
  visiting sibling routes. Authentication and Expense each use one path-less
  module with full RouteEnum URLs and root-owned binds; do not split them into
  dependencies/form/list modules. Never mount sibling features at `/`: their
  bind scopes collide in Modular 7.1.1. Root-owned factory binds do not make Blocs
  singletons; screens/provide still own their instances. Logout visibility and
  the real app's expense route composition have regression tests.
- Navigate in the responsible widget/mixin with its BuildContext. Route arguments
  contain data, not functions. Expense editing returns a confirmed entity.
  ExpensesScreen owns direct edit/back navigation; Dashboard and Metrics refresh
  on every list return, including unchanged lists, without intercepting back.
  Local visual composition callbacks remain valid.
- Read `openspec/README.md` before applying historical specs. Archived Supabase,
  RPC, CommandIt and old lifecycle descriptions do not override current rules.
