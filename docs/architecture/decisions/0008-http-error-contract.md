# ADR 0008: The HTTP error contract

> **Superseded by [ADR 0014](0014-http-response-envelope.md).** The status/oracle policy described below is
> still binding; the structural shape (`ErrorResponse` as a single object with an `errors` sub-list) is not
> — the error body is now always the top-level array `ErrorsResponse`. Kept for historical context.

The HTTP error contract is cross-cutting, so it lives in `core/infrastructure/http/`, not in any
feature, split by kind the same way a feature's HTTP slice is: the shared response DTOs —
`ErrorResponse(code, message, errors)` with an optional `errors: List<FieldErrorResponse>` (each `field` +
`message`) that stays empty for scalar failures — plus the shared response builders that shape that body
at a status (`badRequest` for the edge/malformed `400`, `unprocessable` for the domain-rejection `422`,
`internalError` for the unexpected `500` — new statuses slot in the same way) live in
`core/infrastructure/http/responses/`, so nothing constructs the body inline; the generic
`ExceptionHandler`s that produce that body live in `core/infrastructure/http/errors/handlers/`.
Those handlers are the *same* annotation-bearing exception as
the controllers: Micronaut discovers each `ExceptionHandler` by exception type (`@Singleton`/`@Produces`,
`@Replaces` over a framework default), so there is no `@Factory` way to declare them and `CoreFactory` never
wires them; `ErrorResponse`/`FieldError` are plain `@Serdeable` DTOs. Every HTTP failure path exits in this
one shape: a failed `@Valid` throws `ConstraintViolationException` → `400` with **one `FieldErrorResponse`
per violated field** (never concatenated; `field` is the property path's final node, so the internal
`method.arg` prefix never leaks); a body that can't be read — invalid JSON (`JsonSyntaxException`), a shape
that fails deserialization before validation (`ConversionErrorException`), or an absent required body
(`UnsatisfiedRouteException`) — maps to a scalar `400` (`MALFORMED_REQUEST`); and any otherwise-unhandled
`Throwable` maps to a neutral `500` (`INTERNAL_ERROR`) whose detail is **logged only, never serialized**,
honouring the non-leak invariant. A domain rejection stays **fail-fast**: the feature's error mapper emits
a single scalar `422` via core's shared `unprocessable` builder — the builder owns the *shape*, the mapper
owns the *policy* (which error → which code/message). Identity's `EmailAlreadyInUse` is never turned into a
`FieldErrorResponse(field = "email")`, which would reintroduce the account-discovery oracle. **The HTTP
status code is itself part of the non-leak invariant**: every domain rejection of a context shares one
status (`422` for identity), so the status can never signal *which* rejection happened. Giving one error a
distinct status — e.g. a "textbook" `409 Conflict` for `EmailAlreadyInUse` while the sibling rejections stay
`422` — leaks exactly what the generic code/message hide: the odd-status-out tells an attacker the e-mail is
registered. It is the same oracle as a per-field error, just carried by the status line. So the `400`/`422`
split is by *kind of failure* (malformed/edge vs. well-formed-but-domain-rejected), never per business rule;
a rule-specific status is only ever acceptable if it is applied uniformly to *all* of a context's domain
rejections at once (an all-or-nothing contract decision, not a per-error tweak) — and even then `422` is the
better semantic fit than `400`, since the payload is syntactically valid. Constraint
violations, malformed bodies, and internal failures are genuinely *thrown*, unlike the domain's sealed
result, which is branched over.
