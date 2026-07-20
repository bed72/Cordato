# ADR 0001: Virtual Objects as a third domain category

Virtual Objects (`domain/virtual_objects/`) are a third category alongside `entities/` and
`value_objects/`: a projection computed at read time from real entities, with no identity of its own,
never persisted, recomputed on every ask. Unlike a value object, it composes/references entities; unlike
an entity, it's never tracked or referenced over time. Examples: the enriched active budget (live budget
+ spent + remaining), the "no budget" catch-all bucket, the couple's combined budget panorama, the
couple's combined expense view. Keep the implementation boring — a plain `data class` assembled by a
domain function/service, no base class or marker interface for the sake of taxonomy. If one starts
needing identity or mutation, that's a sign it slipped into being an entity, not a reason to formalize
the category further.
