# ADR 0012: Edge authentication

Edge authentication is a declarative guard, cross-cutting so it lives in `core`, not any feature.
Sign-in *mints* the session (opaque token, `hashToken` stored); the consuming side lives in
`core/infrastructure/http/authentication/` and turns a presented Bearer into an authenticated actor. It is
organized by kind, each in its own subpackage: `actors/AuthenticatedActor.kt` (the **authenticated actor**
— the edge category naming the driving-side answer to "who is calling this route?"; a plain `data class`
carrying the `personId` **and** the current `sessionId` (the latter for session-scoped operations, e.g.
revoking the person's other sessions while sparing the current one), not a value class, to dodge the
typed-binding pitfall; its `internal const ATTRIBUTE`/`ATTRIBUTE_SESSION` request-attribute keys live in the
type's `companion`, namespaced under the type they transport rather than as scattered top-level constants —
`personId`/`sessionId` are raw `String`s throughout, so this is edge-binding machinery, not a domain type; the
filter stashes both and the binder reads both, so an absent attribute leaves the binding unsatisfied), `annotations/Authenticated.kt` (the marker annotation on a
`@Controller`/handler that declares the route protected — declaring it is what protects, decoupled from
whether the handler reads the actor), `filters/AuthenticatedFilter.kt` (the `@ServerFilter` guard, with a
file-private `bearerToken()` extension), and `binders/AuthenticatedActorArgumentBinder.kt` (the honest
binder). The
**`@ServerFilter` is the same annotation-discovered driving exception as the controllers and
`ExceptionHandler`s** — there is no `@Factory` way to declare a filter, so it wires itself and is *not* in
`CoreFactory`; it reads the matched route via `RouteAttributes.getRouteMatch(request)` (the non-deprecated
MN4 accessor), skips any route without `@Authenticated` (sign-up/sign-in stay open, no session resolution),
and on a protected route resolves the live session through `SessionRepository.findActiveByToken(token,
clock())` (injected as `BeanProvider` so building the singleton at boot doesn't realize the `DataSource`).
A live session → the person id is stashed in a request attribute and the request proceeds; **no live
session → the filter *returns* (never throws) the neutral `401` directly via the shared `unauthorized(...)`
builder** (code `UNAUTHENTICATED`, message by i18n key `error.authentication.message`, **no**
`WWW-Authenticate`, token never echoed). Returning-not-throwing mirrors how identity's sign-in mapper
already emits the identical `401` and sidesteps any dependence on filter-thrown exceptions reaching a
handler — so there is deliberately **no** `UnauthenticatedException`/handler. Absent, malformed, expired and
revoked tokens collapse to one response, so neither status nor body reveals the cause. The
`AuthenticatedActorArgumentBinder` is annotation-free and wired in `CoreFactory` (a `@Singleton
TypedRequestArgumentBinder<AuthenticatedActor>`); it **only reads** the attribute the filter set — no
session lookup, no `401` — so an absent attribute (a handler asking for the actor on a route that isn't
`@Authenticated`) is an unsatisfied binding, a programming error with no legitimate request path.
