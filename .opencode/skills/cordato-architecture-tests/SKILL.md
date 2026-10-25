---
name: cordato-architecture-tests
description: Use when adding, reviewing, or running Cordato architecture tests for Flutter layers, bounded-context imports, modules, or dependency direction.
---

# Cordato Architecture Tests

Use static architecture tests for rules that can be checked from the source
tree. Keep the tests independent of Supabase and avoid runtime setup.

## Required Checks

- Scan only `lib/`, never test fixtures or generated files.
- Detect `package:cordato/features/<context>/...` imports and report the source file and target context.
- Reject sibling business-context imports from `expense` and `budget`.
- Reject `family` imports of `insight` and allow its `budget`/`expense` imports only from infrastructure.
- Allow `insight` imports of `budget`, `expense`, and `family` only from infrastructure.
- Reject imports of `data`, `infrastructure`, or `presentation` from a feature's `domain`.
- Reject Supabase and storage SDK imports from `domain` and `presentation`.
- Contracts belong in application, independent of Flutter, SDKs and adapters;
  domain must not depend on application. Presentation consumes contracts and
  application exceptions, not concrete repositories, core clients or DTOs.
- Authentication and Session do not import each other. Settings logout may
  consume only Authentication application contracts/exceptions.
- New/migrated flows must not restore CommandIt, Either, response wrappers or
  delegation-only data sources. Historical RPC checks do not establish the
  current HTTP implementation's backend authorization guarantees.

## Test Design

- Prefer a small test in `test/architecture/` using `dart:io` and `flutter_test`.
- Make failures actionable: include the violated rule, source path, and imported path.
- Treat an absent future feature directory as valid; the test should enforce rules as contexts are added.
- Do not encode implementation details that are not architectural contracts.
- Add module and route tests separately; import scanning cannot prove dependency injection behavior.

## Modular V7 Runtime Coverage

- Sign-in is the page-scoped pilot: test constructor DI through route `provide`,
  one Bloc per page, stable instance on rebuild, closing on exit, recreation on
  return and no late effects after pending operations. The scope closes the
  Bloc, not the screen or test teardown acting as a second owner.
- Other screens still use their stable factories and screen-owned lifecycle;
  Session remains globally owned by AppWidget. Do not declare all migrated.
- Test cross-feature dependency resolution without visiting sibling routes;
  registered RouteEnum paths alone do not prove DI works. Keep the unresolved
  logout repository visibility failure visible until its implementation is fixed.
- Test direct BuildContext navigation, typed confirmed/cancelled edit returns,
  and list-return refresh via app bar and system back without route callbacks.
  E2E gesture validation cannot be claimed from widget tests alone.

Run the focused test with:

```bash
flutter test test/architecture
```

Then run the complete checks:

```bash
flutter analyze
flutter test
```
