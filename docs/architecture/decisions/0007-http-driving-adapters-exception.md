# ADR 0007: HTTP driving adapters are the annotation-bearing exception

HTTP driving adapters are the one annotation-bearing exception to the "adapters are annotation-free,
wired in `main/`" rule. A `@Controller` in `features/<context>/infrastructure/http/controllers/` (the
*driving*/inbound side, kept separate from the *driven* `infrastructure/adapters/`) carries Micronaut
routing annotations (`@Controller`, `@Post`, `@Body`, `@Validated`) and is discovered directly — the
router registers routes by scanning for them at compile time, so there is no `@Factory` way to declare a
route. It still depends only on the pure use case (the factory-provided bean, constructor-injected), so no
`application`/`domain` type gets introspected; the exception is scoped to the controller alone.

The rest of a feature's HTTP slice lives in `requests/`, `responses/`, `mappers/` (its `errors/` mapper,
e.g. identity's `SignUpErrorResponseMapper`, maps that context's own domain errors to a status + body).
Request/response DTOs are `@Serdeable` data classes. **Validation runs in two places on purpose, but from
one definition:** the request carries Bean Validation constraints (`@NotBlank`/`@Size`/`@Pattern`) for
early, per-field `400`s, while the domain value object stays the single, unbypassable authority for the
invariant. Every edge constraint that mirrors a domain rule *references the value object's own
`const`/pattern* (e.g. `@Size(max = NameValueObject.MAX_LENGTH)`, `@Pattern(regexp =
EmailValueObject.PATTERN)`) — never a copied literal — so the two can't drift; the edge is a
deliberately-equal-or-stricter guard (it sees the raw value, before the value object's trim/lowercase). A
field with **no** value object (pure transport: paging, filters) is validated *only* at the edge.
