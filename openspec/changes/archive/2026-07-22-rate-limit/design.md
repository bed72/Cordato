## Context

The HTTP edge in `core` already has two `@ServerFilter(MATCH_ALL_PATTERN)` cross-cutting filters —
`HttpRequestLoggingFilter` (`Order(HIGHEST_PRECEDENCE)`, mints a correlation id) and `AuthenticatedFilter`
(reads the matched route, resolves `AuthenticatedActor` or returns a neutral `401`) — and a `CachePort`/
`CacheAdapter` over Valkey used today by `expense`'s read cache and generation-based invalidation. Rate
limiting is a third cross-cutting filter that composes both: it needs the atomic counter `cache-valkey`
already provides, and it needs to run in the same filter chain, before `AuthenticatedFilter`, so an
unauthenticated flood against a protected route is still counted (per proposal.md).

No proxy/load balancer sits in front of the app today (`Main.kt` boots the embedded Netty server directly),
so there is no `X-Forwarded-For` trust boundary to reason about yet.

## Goals / Non-Goals

**Goals:**
- Bound request volume per client IP within a rolling time window, on every route, decided **before** the
  request reaches `AuthenticatedFilter` — so a flood (valid or forged tokens) against a protected route is
  itself bounded, protecting the session lookup it would otherwise trigger unthrottled.
- Give auth-sensitive routes (`sign-up`, `sign-in`, couple invite creation) a stricter budget than the rest
  of the API, without hardcoding either budget as a literal.
- Reuse the existing `CachePort`/Valkey kernel rather than introduce a new dependency (e.g. Bucket4j,
  Resilience4j) or an in-memory limiter that would silently stop working the moment the app runs as more
  than one instance.
- Keep the 429 failure path indistinguishable in *shape* from every other failure (same `errors` envelope),
  per `http-error-handling`.

**Non-Goals:**
- Per-person (`personId`) keying for authenticated traffic — see Decisions below for why the filter's
  required ordering (before `AuthenticatedFilter`) makes this unavailable in v1, and Open Questions for the
  fast-follow.
- Sliding-window or token-bucket precision (no smoothing of the edge-of-window burst) — fixed-window is the
  explicit v1 choice; revisit only if abuse patterns actually exploit the boundary.
- Per-plan/per-tenant differentiated limits (there is no plan/tenant concept in Cordato).
- Trusting `X-Forwarded-For`/`X-Real-IP` — no reverse proxy exists yet; `request.remoteAddress` is the
  client IP for now. Revisit when a proxy/LB is introduced (tracked as an open question below).
- A distributed lock or Lua script for perfect atomicity across the increment+expire pair — the two-call
  approach is accepted (see Risks).

## Decisions

### Fixed-window key shape: `rate_limit:<tier>:<ip>:<window_start>`

`window_start` is `floor(clock().epochSecond / windowSeconds) * windowSeconds`, computed from `ClockPort`
(not `System.currentTimeMillis()`) so the filter stays deterministic under `FakeClockPort` in tests, exactly
like every other core component. `<ip>` is `request.remoteAddress.hostString` (see the identity decision
below for why this is IP and never `personId` in v1). `<tier>` is `general` or `sensitive`. Encoding the
window boundary in the key itself (rather than reading-then-comparing a stored timestamp) is what makes a
plain `INCR` sufficient — the key for a new window has never been incremented, so it starts at `1` for free,
exactly how `cache-valkey`'s generation counter already behaves.

**Alternative considered**: a Lua script computing window+limit server-side in one round trip. Rejected for
v1 — two round trips (`increment` then conditionally `expire`) is simple, fits the existing `CachePort`
shape, and the residual race (below) is an acceptable trade for not introducing scripted Redis commands
into the codebase's first cache consumer to need them.

### Identity is IP-only in v1 — the filter ordering that protects the session lookup rules out `personId`

The filter must run **before** `AuthenticatedFilter` to satisfy the primary goal (bound the session-lookup
DB call itself, and count auth-guessing floods against protected routes). Micronaut's `@ServerFilter` chain
executes `@RequestFilter` methods in ascending `@Order` and unwinds `@ResponseFilter` methods in the reverse
order around the handler — so a filter ordered before `AuthenticatedFilter` runs its request phase strictly
before `AuthenticatedFilter` has resolved (or rejected) anything, meaning the `AuthenticatedActor` request
attribute does not exist yet at the point the rate-limit decision has to be made. There is no ordering that
gets both "count floods against protected routes" and "key authenticated requests by `personId`" out of a
single pre-handler check: ordering the filter *after* `AuthenticatedFilter` would get `personId`, but then
any request `AuthenticatedFilter` itself rejects (missing/invalid/expired token) short-circuits the chain
before the rate limiter ever runs — exactly the flood this filter exists to bound. IP-keying for everything
is therefore the only shape consistent with the stated primary goal. Layering a *second*, `personId`-keyed
check purely for authenticated business routes is possible later (see Open Questions) but is a distinct
mechanism, not a variant of this one, so it is out of scope here rather than half-built now.

### `CachePort.expire` is `EXPIRE ... NX`, not a plain `EXPIRE`

`CachePort` gains `fun expire(key: String, ttl: Duration)`, implemented via Lettuce's `EXPIRE key seconds NX`
(only arms a TTL if the key currently has none). The filter calls it **unconditionally after every
`increment`**, not just when the returned count is `1`. Because `NX` makes the operation idempotent, this
removes the need for an `if (count == 1)` branch and the race that branch would otherwise have: two
concurrent requests both observing `count == 1` (impossible with a real atomic `INCR`, but worth naming) or
a crash between the `increment` and a conditional `expire` on the very first request of a window would
either way leave the TTL correctly armed exactly once, by whichever request's `expire` call lands, without
double-arming or overwriting a shorter TTL onto an already-running window.

**Alternative considered**: reuse `set(key, value, ttl)` to both write and expire. Rejected — `set` overwrites
the counter's value, which would race destructively against a concurrent `increment` (the increment could be
clobbered back to the literal string just written).

### Tier assignment is a route annotation, not a config path list

A new `@RateLimited(tier: RateLimitTierEnum = RateLimitTierEnum.SENSITIVE)` marker annotation (mirroring
`@Authenticated`'s "declaring it is what protects" posture) is placed on the three sensitive handlers
(`SignUpController`, `SignInController`, the couple-invite creation handler). The filter reads the matched
route the same way `AuthenticatedFilter` already does (`RouteAttributes.getRouteMatch(request)`); a route
without the annotation defaults to the `GENERAL` tier — since scope is the *whole* API (per proposal.md),
every route is limited by default, and the annotation only *tightens* specific ones, so no route can be
accidentally left unlimited by a missing annotation.

**Alternative considered**: a config-driven list of `method:path` patterns for the sensitive tier (what was
floated during the initial discussion). Rejected in favor of the annotation once the existing `@Authenticated`
precedent was found — keeping "which routes are sensitive" next to the handler declaration (compile-checked,
refactor-safe) is more consistent with this codebase's existing pattern than a string-matched external list,
which would silently stop matching after a path rename. The *numeric* budgets (limit, window) stay in
`application.properties` — only the tier-to-route mapping moves to the annotation.

### Config shape

```properties
cordato.rate-limit.general.limit=100
cordato.rate-limit.general.window=PT1M
cordato.rate-limit.sensitive.limit=5
cordato.rate-limit.sensitive.window=PT1M
```
Bound to a `@ConfigurationProperties("cordato.rate-limit")` class (or two, one per tier) in
`core/infrastructure/http/rate_limit/`, injected into the filter — same idiom `DatabaseConfiguration`/
`ValkeyConfiguration` already use for external config.

### Response shape

A new `tooManyRequests(code: String, message: String, retryAfterSeconds: Long): HttpResponse<ErrorsResponse>`
builder alongside `badRequest`/`unauthorized`/`unprocessable`/`internalError` in
`core/infrastructure/http/responses/ErrorResponse.kt`, scalar-only (no `source`, matching how `401` is
scalar-only), setting `Retry-After: <retryAfterSeconds>` as a response header (not a body field) — the same
"metadata belongs in a header, not the envelope" precedent `Correlation-Id` already set.
`retryAfterSeconds` is the current window's remaining lifetime, derived from the same `window_start` used to
build the cache key (`windowSeconds - (now - window_start)`), not a hardcoded constant — a client retrying
after a full `window` has always crossed into a fresh window.

## Risks / Trade-offs

- **[Risk]** Two-round-trip `increment` + `expire` is not a single atomic operation → **Mitigation**: `NX`
  semantics make `expire` idempotent and safe to call every request; the only failure mode is a process
  crash between the two calls on a window's very first request, which would leave that one key permanently
  un-expired (that identity effectively locked at its last count until the key is manually cleared) — judged
  acceptable likelihood for a rate limiter (not a billing/security-critical counter), and easy to detect
  operationally (a `TTL`-less `rate_limit:*` key) if it ever happens.
- **[Risk]** `request.remoteAddress` is the literal TCP peer address, which breaks under any future reverse
  proxy/load balancer (every request would appear to come from the proxy's IP, collapsing all clients into
  one bucket) → **Mitigation**: explicitly out of scope now (no proxy exists); flagged as an open question so
  it isn't silently forgotten when one is introduced.
- **[Risk]** IP-based keying can over-penalize many legitimate users behind the same NAT/corporate proxy →
  **Mitigation**: accepted for v1, since the sensitive tier (where this matters most — signup/login) is
  scoped generously enough (see config) that normal shared-IP traffic shouldn't realistically collide; revisit
  if it does.
- **[Trade-off]** Fixed-window allows up to 2x the limit in a burst straddling a window boundary → accepted
  per proposal.md's explicit v1 algorithm choice.

## Migration Plan

Purely additive — a new filter, a new `CachePort` method, a new error code, no changes to existing request/
response shapes on the success path. Ships in one change: no flag needed, no phased rollout, since a
generous default `general` limit (e.g. 100/min) is very unlikely to affect real traffic while still closing
the abuse gap. Rollback is deleting/disabling the filter (or setting limits high enough to be a no-op) — no
data migration involved (Valkey keys are TTL'd, self-cleaning).

## Open Questions

- When a reverse proxy/load balancer is introduced, which header (`X-Forwarded-For`, `X-Real-IP`) should be
  trusted for client IP, and from which hop — needs its own decision at that time, not now.
- Should the `sensitive` tier's numeric defaults differ meaningfully from `general`'s in the actual shipped
  `application.properties`, or is that a product/ops call to make after observing real traffic? (Values above
  are illustrative, not final.)
- Fast-follow: a **second**, `personId`-keyed check for authenticated business routes (layered after
  `AuthenticatedFilter`, once the actor is known) to stop an authenticated actor from dodging the general
  tier by rotating IPs. Deliberately not this change — it is a distinct mechanism (a second filter or a
  second check inside a differently-ordered pass), not a variant of the IP-keyed pre-auth gate, and the v1
  IP-based gate already bounds the abuse this change set out to fix.
