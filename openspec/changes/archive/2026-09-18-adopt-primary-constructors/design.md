## Context

Primary constructors became stable in Dart 3.13. They combine a type's canonical generative constructor and field declarations in the class or enum header without changing runtime semantics. Cordato already declares `sdk: ^3.13.2`, and the current toolchain accepts the syntax without an experiment flag.

The repository contains approximately 190 Dart files under `lib/`, 40 under `test/`, 224 class declarations and 162 explicit constructors. The current worktree already pilots primary constructors in `IconWidget`, `CordatoPreview`, `_LocaleReadyWidget`, `RouteEnum` and `AssetEnum`. A full inventory identified roughly 134 additional direct conversions plus manual-review cases involving commands, private domain constructors, assertions and lifecycle initialization.

This is a cross-cutting source convention rather than a product capability or architecture change. The implementation must respect the existing preference for small diffs, preserve user changes and avoid turning a syntax adoption into a repository-wide rewrite.

## Goals / Non-Goals

**Goals:**

- Define a single, reviewable rule for primary constructor usage in Cordato.
- Remove field-and-assignment boilerplate in types where the new syntax is clearer.
- Preserve source contracts, const construction, DI tear-offs and runtime behavior during conversion.
- Distinguish direct conversions from cases requiring manual semantic review.
- Make the Dart 3.13 tooling dependency explicit to contributors.
- Validate the existing pilot declarations against the same rules that future code will follow.
- Complete the initial migration across every eligible existing declaration under `lib/`.

**Non-Goals:**

- Introduce a custom lint, analyzer plugin, code generator or formatting rule.
- Require primary constructors where they increase cognitive load or add no value.
- Change constructor APIs, class responsibilities, dependency injection, architecture or product behavior.
- Refactor command lifecycle, factories, stream subscriptions or domain validation while changing syntax.
- Add widget tests for syntax-only presentation changes.

## Decisions

### Prefer primary constructors, do not mandate them universally

Primary constructors will be the preferred form for a type with one canonical generative constructor whose inputs are stored unchanged or forwarded to `super`. Typical candidates are immutable widgets, enums with associated data, failures, simple entities/value objects and repository implementations that only store dependencies.

Traditional constructors remain valid when they make ordering, lifecycle or construction alternatives clearer. A universal mandate was rejected because `State` classes, interfaces, mocks and implicit empty constructors have no boilerplate to remove, while complex commands can become harder to understand through primary initializer scopes.

### Use an eligibility matrix during review

Declarations fall into three categories:

| Category | Examples | Decision |
|---|---|---|
| Direct | Final fields assigned from parameters, `super.key`, simple super parameters, enum payloads | Prefer a primary constructor |
| Manual review | Commands, initializer lists, asserts, constructor bodies, private named constructors, late fields, subscriptions | Convert only when semantics and readability are preserved |
| Retain/no action | Factories, redirects, multiple required generative paths, `State` classes, interfaces, mocks, explicit or implicit empty constructors without state | Keep the required in-body form or omit an explicit primary constructor |

Factories and redirecting constructors can coexist with a primary constructor, but are not replaced by it. A class that needs multiple non-redirecting generative constructors cannot use a primary constructor for only one path.

### Preserve the constructor contract exactly

A syntax conversion is not an opportunity to redesign a constructor. The constructor name, visibility, named and positional parameter names, types, nullability, required modifiers, defaults, const behavior and super forwarding must remain equivalent. Unnamed primary constructors continue to expose `Type.new`, so existing `flutter_modular` registrations remain valid when their signatures are unchanged.

Conversion-only diffs will also avoid unrelated body rewrites or newly exposed parameters. This is important for the current `CordatoPreview` pilot, whose conversion must be reviewed separately from any decision to expose additional superclass parameters.

The alternative of allowing opportunistic API cleanup during migration was rejected because it makes regressions difficult to attribute and undermines the claim that adoption is syntax-only.

### Make field induction explicit

Immutable state uses `final Type name` declaring parameters. Mutable induced fields use `var` only when mutation is intentional and already part of the design. Inputs used only to compute other fields remain typed non-declaring parameters, without `final` or `var`.

Super parameters remain appropriate for direct forwarding. Named private declaring parameters require extra review because Dart removes the leading underscore at the call site; they are allowed only when the resulting public parameter name matches the existing API.

For constant construction, `const` moves to the type header, such as `final class const Example(...)`. Because constant primary constructors cannot have a body, any required execution body keeps a traditional constructor or requires a separately justified design.

### Complete one baseline migration, then adopt incrementally

This change will document the convention, validate the five initial pilots and convert every other eligible declaration under `lib/`. The broad source scope is explicit and each conversion remains syntax-only, with complex constructors reviewed individually and retained when primary syntax would obscure lifecycle or invariants.

After this baseline, future features apply the convention to new eligible declarations, and any declaration retained for a concrete reason is reconsidered only when its construction design changes or another focused migration selects it.

### Enforce through contributor guidance and ordinary verification

Contributor guidance is the operational source of truth for eligibility, examples and review rules. Architecture documentation records primary constructors as the durable construction standard across layers while making clear that syntax does not alter dependency direction. Product documentation remains focused on setup unless its toolchain instructions need an explicit minimum Flutter version.

No lint currently enforces primary constructor preference, and a custom analyzer rule is disproportionate. Review, `dart format`, `flutter analyze` and existing layer tests provide sufficient enforcement. UI tests are not added for a syntax-only widget conversion under the project's Maestro policy.

## Risks / Trade-offs

- [Contributors use Dart 3.12 or older and encounter parse failures] -> Keep the lower bound at Dart 3.13 or newer and document the requirement; package resolution rejects unsupported SDKs.
- [A mechanical conversion changes a signature or const behavior] -> Compare constructor contracts and call sites before and after, and keep conversion-only diffs free of API additions.
- [Initializer scope and constructor body scope are misunderstood] -> Treat commands, derived fields, assertions, late fields and body logic as manual-review cases with relevant tests.
- [The codebase temporarily contains both styles] -> Accept coexistence as the cost of incremental migration; use the documented rule for all new or actively changed eligible code.
- [Factories or redirects are accidentally removed] -> Keep them in-body and verify they target or return the same construction path.
- [Primary syntax makes a complex type less readable] -> Retain the traditional constructor; preference is conditional on equal or better clarity.
- [No lint guarantees uniform enforcement] -> Keep criteria concrete in the contributor guidance and use code review instead of adding analyzer infrastructure for a syntax preference.
- [A broad migration conflicts with concurrent feature work] -> Keep every edit declaration-local, preserve unrelated work in touched files and verify the complete diff before formatting and tests.

## Migration Plan

1. Confirm `pubspec.yaml` continues to require Dart 3.13 or newer and avoid adding experiment flags or dependencies.
2. Add the primary constructor eligibility, preservation and exception rules to the contributor guidance.
3. Inventory every explicit constructor under `lib/` and classify direct conversions, manual-review cases and retained declarations.
4. Review the five current pilots and convert every other eligible declaration, separating unrelated API or body changes from syntax conversion.
5. Format only the Dart files changed by the implementation.
6. Run `flutter analyze` and `flutter test`; record failures that predate or are unrelated to this change.
7. Apply the convention incrementally to future declarations after the baseline migration.

Rollback requires reverting only the affected declaration headers to equivalent field declarations and traditional constructors. No data, deployment or runtime migration is involved.

## Open Questions

Nenhuma. A migração inicial completa, seguida por adoção incremental e sem lint customizado, é a decisão desta change.
