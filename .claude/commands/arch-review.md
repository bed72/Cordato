---
name: "Arch Review"
description: Audit the current diff against Cordato's architecture and HTTP conventions, then apply purely structural/naming fixes.
category: Quality
tags: [architecture, review, hexagonal, cordato]
---

Audit the working changes against the conventions in `CLAUDE.md` and the `feature-layers` / `http-slice` skills, report every violation with `file:line` and the rule it breaks, then apply **only non-behavioral** fixes. This complements the Konsist `ArchitectureTest` (which fails the build on layering) with the rules a compiler can't check: naming, non-leak, error-contract shape, i18n-by-key, derive-don't-store.

**This is not a bug review.** It checks *structure, placement, naming, and contract shape* — use `/code-review` for correctness. It never authorizes behavior: if a violation can only be fixed by changing what the code *does*, report it and stop (that needs an OpenSpec change, per SDD).

**Input**: an optional path or scope (`/arch-review src/main/.../identity`). If omitted, review the current diff (`git diff` + staged + untracked under `src/`). Announce the scope reviewed.

## Steps

1. **Gather the diff**
   ```bash
   git status --short && git diff --stat HEAD
   ```
   Read every changed/added `.kt` (and `messages.properties` / `application.properties` if touched). Ignore `build/` and generated jOOQ/OpenAPI output.

2. **Load the rules** — skim `CLAUDE.md` (Architecture + Design decisions), and the `feature-layers` + `http-slice` skills. These are the source of truth; the checklist below is a lens, not a replacement.

3. **Check each changed file against the checklist** (below). For every hit, record `file:line`, the exact rule, and whether the fix is *structural* (safe to apply) or *behavioral* (report only).

4. **Report**, most-severe first, grouped by file. Then apply the structural fixes and show what changed. Leave behavioral findings for the user with a note that they need a spec.

5. **Verify** — run `./gradlew test` (at least `ArchitectureTest`) if any file moved or a suffix/import changed, so the build still passes.

## Checklist

**Layering & dependencies (also enforced by Konsist — flag early)**
- `domain/` imports nothing from `application/`, `infrastructure/`, Micronaut, `jakarta.inject`, or any library.
- `application/` never imports `infrastructure/` or a DI/framework annotation.
- Only `couple` references a sibling context (`budget`/`expense`), and only through a port it defines in `couple/application/ports/`, implemented in `couple/infrastructure/adapters/`. `identity`/`budget`/`expense` never import a sibling.
- **Derive, don't store**: no foreign key added for query convenience (e.g. `Expense` referencing `Budget`); membership is computed at read time.

**Naming & placement (`<Meaning><Category>`, suffix = folder)**
- `…Entity` / `…ValueObject` / `…VirtualObject` / `…Enum` / `…Error` / `…Command` / `…Result` / `…UseCase` / `…Port` / `…Repository` / `…Adapter` / `…Factory` each live in the matching folder.
- Value objects: `@JvmInline value class`, private ctor + `of()` returning null on invalid, `MAX_LENGTH`/`PATTERN` as `const`.
- Errors are `sealed` and **returned**, never thrown; results are `sealed`. Money is integer cents / fixed-scale `BigDecimal`, never `Double`; BRL only.
- Mappers are `internal` extension functions (`toRecord`/`toEntity`/`toCommand`/`toResponse`), never an object/interface.

**DI wiring**
- Wiring lives in the package's `main/` subpackage — one `@Factory` per package (`CoreFactory`, `<Context>Factory`). `application`/`domain` carry no DI annotation. A feature factory inherits core's bindings, never re-declares them.
- The only annotation-bearing infra types discovered directly (not via `@Factory`): `@Controller`s and core's `ExceptionHandler`s. Anything else annotated in infra is a smell.

**HTTP slice**
- Controller is thin: routing/validation + delegation + sealed-result branch; no inline error bodies; success method carries `@Status(...)`.
- OpenAPI annotations live on `<Controller>Doc`, not the controller. DTOs are `@Serdeable`; response DTOs never leak password material.
- Edge constraints reference the value object's own `const`/`PATTERN` (no copied literal). Pure-transport fields validated only at the edge.
- Every human-readable message is `{key}` into `i18n/messages.properties`; error **codes** stay inline constants (not localized). New message added to the bundle for every new key referenced.

**Non-leak invariant (identity / anything authenticating)**
- No existence/credential conflict rendered as `FieldErrorResponse(field = …)`.
- **Status-as-oracle**: all of a context's domain rejections share one status (`422`). A single error with a distinct status (`409`/`400`) while siblings stay `422` is a leak — flag it. (`400` vs `422` split is by *kind of failure*, never per business rule.)
- The `500` path serializes no internal detail (logged only).

## Output

```
## Arch Review — <scope>

### Violations
1. [structural] path/to/File.kt:42 — <rule broken> → <fix applied/proposed>
2. [behavioral] path/to/Other.kt:88 — <rule broken> → needs a spec (not auto-fixed)
...

### Fixes applied
- Moved X → Y / renamed Z / extracted literal to key `foo.bar`
(none, if clean)

### Needs your call
- <behavioral findings, each with why it can't be auto-fixed>

Clean on: <checklist areas with no findings>
```

If the diff is clean, say so plainly and list what was checked — don't invent findings.

## Guardrails
- Report `file:line` for every finding; never a vague "somewhere in the HTTP layer."
- Apply only structural/naming/i18n-extraction fixes. Anything that changes runtime behavior → report, don't touch.
- If a fix would need an OpenSpec change, say so and point at `/opsx:propose`.
- Don't duplicate the Konsist test's job silently — if a finding is one the arch test already fails on, note it so the user runs `./gradlew test`.
