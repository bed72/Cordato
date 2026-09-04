---
name: cordato-architecture
description: Use ONLY when creating, reviewing, or changing Cordato features, modules, repositories, routes, or bounded-context boundaries; enforce the validated financial domain and Flutter layering.
---

# Cordato Architecture

Use this skill for architecture-sensitive work in the Cordato Flutter app.

## Source Of Truth

Read these files before changing architecture or a financial feature:

1. `AGENTS.md` for project rules and the validated product model.
2. `ARCHITECTURE.md` for Flutter layers, modules, routes, and dependency rules.
3. `README.md` for product scope and current implementation status.
4. The affected feature files and their tests.

The Kotlin backend at `/Users/gabrielramos/Code/Me/BackEnd/Kotlin/Cordato` is a
domain reference only. Do not copy its package structure into Flutter.

## Product Boundaries

- `expense` owns individual spending facts.
- `budget` owns individual planned ceilings by inclusive date range.
- `couple` is a read-only lens over two people and owns no financial data.
- `insight` is a read-only projection with no persistence of its own.
- `authentication` owns the Supabase Auth magic-link flow, not a recreated `identity` context.
- `dashboard` is presentation/composition, not a business bounded context.
- `chat` is out of scope and must not be introduced without an explicit product decision.

Preserve these invariants:

- money is positive integer cents in BRL;
- expenses never reference budgets; budget membership is derived from dates;
- live budgets of one person cannot overlap;
- pairing never grants write access to another person's data;
- dissolving a couple does not alter individual data;
- couple views and insights are recomputed and not persisted as source data.

## Dependency Rules

- Keep dependencies inward: presentation -> domain contracts -> data -> infrastructure.
- Keep Supabase, storage, and plugins out of domain and presentation.
- `expense` and `budget` do not import sibling business contexts.
- `couple` may read `budget` and `expense` only through its own contracts, with concrete adapters at the infrastructure edge.
- `insight` may read `budget`, `expense`, and `couple` only through its own contracts, with concrete adapters at the infrastructure edge.
- Owner contexts must never depend on `couple` or `insight`.
- Do not add direct imports of another context's implementation to bypass its contract.

## Workflow

1. Identify the owning bounded context before creating a file.
2. Keep domain rules and contracts framework-free.
3. Put Supabase queries and SDK translation in infrastructure.
4. Add or update the architecture test for any new dependency direction.
5. Add behavior tests in the affected layer.
6. Run `flutter analyze` and `flutter test` before finishing.

When a proposed change conflicts with these boundaries, stop and ask for a
product or architecture decision instead of weakening the rule silently.
