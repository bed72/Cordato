# ADR 0015: HTTP rate limiting

Rate limiting is a third cross-cutting `@ServerFilter`, alongside `HttpRequestLoggingFilter` and
`AuthenticatedFilter`, living in `core/infrastructure/http/rate_limit/`. It applies a **fixed-window**
counter to **every** route, via the existing `CachePort`/Valkey kernel — no new dependency (Bucket4j,
Resilience4j) and no in-memory limiter, which would silently stop working the moment the app runs as more
than one instance.

**Ordering: before `AuthenticatedFilter`, and what that costs.** `RateLimitFilter` is `@Order
(Ordered.HIGHEST_PRECEDENCE + 1)` — right after `HttpRequestLoggingFilter`'s `HIGHEST_PRECEDENCE`, and
before `AuthenticatedFilter` (default order `0`). This is required so a flood of invalid/expired tokens
against a protected route is bounded *before* it can trigger the session-lookup DB call, not after. The
cost is that `AuthenticatedActor` is never resolvable at the point the rate-limit decision has to be made
— there is no ordering that gets both "count floods against protected routes" and "key by `personId`" out
of a single pre-handler check, since ordering after `AuthenticatedFilter` would mean any request it itself
rejects never reaches the limiter at all. Identity is therefore **IP-only in v1** (`request.remoteAddress
.hostString`), for every route, authenticated or not. A `personId`-keyed check for authenticated business
routes is a distinct, second mechanism (layered after `AuthenticatedFilter`) — deliberately not built here.
`request.remoteAddress` is also the literal TCP peer address with no reverse proxy in front of the app
today; trusting `X-Forwarded-For`/`X-Real-IP` is an open question for whenever one is introduced.

**The fixed-window key encodes its own boundary.** The cache key is `rate_limit:<tier>:<ip>:<window_start>`,
where `tier` is `general`/`sensitive`, `window_start` is `floor(clock().epochSecond / windowSeconds) *
windowSeconds` — derived from `ClockPort`, never `System.currentTimeMillis()`, so the filter stays
deterministic under a fake clock in tests. Baking the window boundary into the key itself is what makes a
plain atomic `CachePort.increment` sufficient: a key for a new window has never been incremented, so it
starts at `1` for free, exactly how `cache-valkey`'s generation counter already behaves — no read-then-
compare against a stored timestamp needed. Fixed-window (not sliding-window/token-bucket) is the explicit
v1 choice; it allows up to 2x the limit in a burst straddling a window boundary, accepted as a trade-off
unless real abuse patterns exploit it.

**`CachePort.expire` is `EXPIRE ... NX`, called unconditionally.** A new primitive, `fun expire(key: String,
ttl: Duration)`, arms a TTL on a key **only if it has none** and never touches its value. The filter calls
`increment` then `expire` unconditionally on every request — not just when the count is `1` — because `NX`
makes the pair idempotent: whichever request's `expire` call lands first (on that window's first hit) wins,
and every later call on the same key is a safe no-op. This sidesteps the race a `count == 1` branch would
have, at the cost of two round trips instead of one atomic Lua script — accepted for v1 as the simpler
shape, fitting `CachePort`'s existing style. `set(key, value, ttl)` was rejected as the TTL-arming primitive
because it overwrites the counter's value, racing destructively against a concurrent `increment`.

**Tier assignment is a route annotation, not a config path list.** `@RateLimited(tier: RateLimitTierEnum =
RateLimitTierEnum.SENSITIVE)` marks a handler as belonging to the stricter `sensitive` tier, mirroring
`@Authenticated`'s "declaring it is what protects" posture — the filter reads the matched route the same
way `AuthenticatedFilter` already does (`RouteAttributes.getRouteMatch`). A route without the annotation
defaults to `general`, so no route is ever left unlimited by a missing annotation — every route is limited
by default, and the annotation only *tightens* specific ones (`sign-up`, `sign-in`; couple invite-creation
once that context has code). The alternative — a config-driven `method:path` pattern list — was rejected: it
would silently stop matching after a path rename, whereas the annotation is compile-checked and
refactor-safe. The *numeric* budgets stay in `application.properties`
(`cordato.rate-limit.{general,sensitive}.{limit,window}`, bound via a `@ConfigurationProperties
("cordato.rate-limit")` type with nested `General`/`Sensitive` classes) — only the tier-to-route mapping
moves to the annotation.

**Response shape.** Exceeding a tier's limit returns the request refused directly from the `@RequestFilter`
method (return-not-throw, mirroring `AuthenticatedFilter`'s `401`) as `429 Too Many Requests` through the
shared `errors` envelope (ADR 0014) — scalar, no `source`, a stable `code` (`RATE_LIMITED`) and an i18n
message (`error.rateLimit.message`, ADR 0009). `Retry-After` carries the current window's remaining seconds
(`windowSeconds - (now - window_start)`, never hardcoded) as a response header, not a body field — the same
"metadata belongs in a header, not the envelope" precedent `Correlation-Id` already set.
