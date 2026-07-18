# ADR 0009: i18n message resolution

HTTP response text is resolved by key from a message bundle, never inlined — i18n-ready. Every
human-readable response message comes from `src/main/resources/i18n/messages.properties` (pt-BR default;
a new language is just a `messages_<locale>.properties` sibling, no code change). `CoreFactory` exposes one
`@Singleton MessageSource = ResourceBundleMessageSource("i18n.messages")` (kept in `CoreFactory`, not a
second `@Factory`, per the "one `@Factory` per package" rule); micronaut-http-server layers a
request-scoped, `Accept-Language`-aware `LocalizedMessageSource` on top of it — injectable into the
`@Singleton` error handlers and the controller, falling back to the default bundle for an absent/unknown
header (never failing the request). The **message** is resolved by key at the policy call site through the
one shared helper `core/infrastructure/i18n/resolve` (fallback-to-key so a missing key never throws
on a response path); the **error `code`** (`INVALID_NAME`, `MALFORMED_REQUEST`, …) stays an inline constant
— it is the machine contract, not presentation text, and is never localized. The shared `badRequest`/
`unprocessable`/`internalError` builders still receive already-resolved strings (they own only shape). Edge
Bean Validation follows the same single origin: each constraint's `message` is a `{key}` into the *same*
bundle (`@NotBlank(message = "{signup.request.name.notBlank}")`), which the validator's interpolator
resolves against the `MessageSource` and re-interpolates for the nested constraint placeholders (`{max}`,
`{min}`); the `regexp`/`max`/`min` bounds still reference the value objects' own constants so the edge
can't drift. The non-leak invariant survives localization: `EmailAlreadyInUse` resolves a generic message
in any language and stays scalar, and the `500` resolves only a generic message with no internal detail.
