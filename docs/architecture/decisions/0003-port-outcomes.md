# ADR 0003: Port outcomes

Port outcomes (`application/outcomes/`, suffix `Outcome`) are a small, dedicated category for the
**enumerated, exhaustive result a *driven* port returns** to name which of several mutually-exclusive things
happened at the boundary, so the use case branches over it in a `when`. It is deliberately none of the
neighbours: not a `Result` (that is the use case's *output to the edge* — the driving side; an outcome is a
repository/adapter's *answer back into* the use case), not a domain `Enum` (it describes what the
datastore/external system *did* — e.g. a unique-constraint collision — never a business rule, so it must not
sit in `domain/`), and not an `Error` (a `success` branch like `UPDATED` is a normal outcome, not a
failure). It is pure and framework-agnostic, so it lives in `application/` next to `outcomes/`, and the use
case maps it to the domain `Result`/`Error` the edge understands. **When to reach for one:** only when a
driven-port operation has **three or more** discrete, caller-relevant outcomes that map to *different*
downstream handling — the trigger is that a `Boolean` would collapse two outcomes that must diverge.
`PersonRepository.updateEmail` is the worked example: `UPDATED` / `EMAIL_TAKEN` / `PERSON_INACTIVE`, where a
`Boolean` would fuse "e-mail taken" (a `422`) with "person no longer active" (a neutral `401`). A two-state
result (updated vs. not — like `updateName`) stays a plain `Boolean`; don't manufacture an `Outcome` for it.
The `Outcome`'s cases are the port's vocabulary, so name them in the persistence/boundary's terms
(`EMAIL_TAKEN`), not the domain error's (`EmailAlreadyInUse`) — the translation is the use case's job.
