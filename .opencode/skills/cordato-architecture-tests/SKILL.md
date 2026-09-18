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
- Reject sibling imports from `expense` and `budget`.
- Reject `family` imports of `insight` and allow its `budget`/`expense` imports only from infrastructure.
- Allow `insight` imports of `budget`, `expense`, and `family` only from infrastructure.
- Reject imports of `data`, `infrastructure`, or `presentation` from a feature's `domain`.
- Reject Supabase and storage SDK imports from `domain` and `presentation`.

## Test Design

- Prefer a small test in `test/architecture/` using `dart:io` and `flutter_test`.
- Make failures actionable: include the violated rule, source path, and imported path.
- Treat an absent future feature directory as valid; the test should enforce rules as contexts are added.
- Do not encode implementation details that are not architectural contracts.
- Add module and route tests separately; import scanning cannot prove dependency injection behavior.

Run the focused test with:

```bash
flutter test test/architecture
```

Then run the complete checks:

```bash
flutter analyze
flutter test
```
