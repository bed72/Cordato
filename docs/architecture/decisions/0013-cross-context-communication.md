# ADR 0013: Cross-context communication

Cross-context communication uses an Anti-Corruption Layer, never a direct import between contexts'
`domain`/`application`, and never data duplication. Concrete case: `couple`'s combined views need
per-person data owned by `budget` and `expense`.
- Dependency direction is one-way: `couple → budget` and `couple → expense`, never the reverse. `budget`
  and `expense` must never reference `couple` — they don't know pairing exists.
- The consumer (`couple`) defines the contract it needs, in its own vocabulary, as a port in
  `couple/application/ports/` (e.g. a `PersonFinancialsPort`).
- `couple/infrastructure/adapters/` implements that port by calling `budget`'s and `expense`'s existing
  public use cases directly (an in-process call — no need for HTTP inside one deployable) and mapping the
  result into couple's own shape.
- `couple`'s own `domain`/`application` never import `budget` or `expense` types — only the port.
- No duplication: combined views (`orçamento do casal`, `gastos do casal`) are never stored, only ever
  recomputed live through the port — derive-don't-store applied across contexts, not just across
  entities.
- `couple` owns composing these combined views; `budget` and `expense` only ever answer their existing
  single-person query, called once per person in the pair. (The `expense` and `budget` READMEs currently
  describe the couple-combined view as if they compute it — that phrasing describes the user-visible
  effect, not implementation ownership; the READMEs have been updated to point this at `couple`.)
