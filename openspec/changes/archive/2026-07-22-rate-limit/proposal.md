## Why

The HTTP edge has no protection against abuse: `POST /sign-up`/`POST /sign-in` can be brute-forced or spammed
with unlimited attempts, and any route can be hammered by a single client without consequence. `core` already
has the two ingredients a rate limiter needs (a distributed atomic counter in `cache-valkey`, and the
`@ServerFilter` cross-cutting pattern proven by `http-request-logging`/`http-authentication-guard`) but nothing
wires them together yet.

## What Changes

- New `RateLimitFilter` (`@ServerFilter(MATCH_ALL_PATTERN)`) in `core/infrastructure/http/rate_limit/filters/`,
  ordered right after `HttpRequestLoggingFilter` and before `AuthenticatedFilter`, so an unauthenticated flood
  against a protected route is still counted.
- Fixed-window counter algorithm over Valkey: one atomic `increment` per request against a window key, with the
  window's TTL armed only on the first hit of that window (new `CachePort.expire` primitive; see `cache-valkey`
  below).
- Two configurable limit tiers, both driven by `application.properties` (no hardcoded numbers): a stricter tier
  for auth-sensitive routes (`POST /sign-up`, `POST /sign-in`, couple invite creation) and a general tier for
  everything else.
- Keying: client IP for every request in v1. The rate-limit decision must happen **before** `AuthenticatedFilter`
  runs (so a session-lookup flood against a protected route is itself bounded), and at that point in the chain
  `AuthenticatedActor` isn't resolvable yet — so `personId`-based keying for authenticated traffic (originally
  floated) is **not** v1 scope; see `design.md` for why, and its Open Questions for the fast-follow.
- On limit exceeded: `429 Too Many Requests` rendered through the shared `errors` envelope (ADR 0014) with a new
  stable `code` (`RATE_LIMITED`), a new i18n message key (ADR 0009), and a `Retry-After` header carrying the
  seconds left in the current window (outside the body, mirroring how `Correlation-Id` is carried).
- `CachePort` gains a new minimal primitive (`expire(key, ttl)`) so the filter can arm a window's TTL right
  after the increment that opens it, without overloading `set` (which stores a value, not just a TTL).

## Capabilities

### New Capabilities
- `http-rate-limiting`: the rate-limit filter itself — fixed-window algorithm, the two configurable tiers, the
  IP/personId keying rule, filter ordering, and the 429 response shape.

### Modified Capabilities
- `cache-valkey`: `CachePort` gains a third atomic primitive, `expire(key, ttl)`, that arms/refreshes a key's
  TTL without touching its value — needed by the fixed-window counter, and available to any future consumer
  that needs the same "increment now, expire once" shape.
- `http-error-handling`: adds a `429 Too Many Requests` failure path to the shared `errors` envelope, alongside
  the existing 400/401/500 paths — a scalar item (no `source`), analogous to how the 401 requirement was added.

## Impact

- **Code**: new files under `core/infrastructure/http/rate_limit/` (filter, config binding) and
  `core/application/driven/ports/` (extended `CachePort`) + `core/infrastructure/adapters/cache/CacheAdapter`
  (extended); `core/infrastructure/http/responses/` (new error code); `i18n/messages.properties` (new key);
  `application.properties` (new config block); `CoreFactory` (filter needs no factory wiring, same as
  `AuthenticatedFilter`/`HttpRequestLoggingFilter`, but the config binding might).
- **APIs**: every route now carries an implicit `429` failure mode; a new `Retry-After` response header on that
  path.
- **Dependencies**: none new — reuses the existing Lettuce/Valkey client already wired for `cache-valkey`.
- **Tests**: mirrors `AuthenticatedFilterTest`'s shape (fake `CachePort`/`FakeCachePort` already exists in
  `src/test/kotlin/com/bed/cordato/core/factories/`, a probe controller in `support/` to drive the filter
  end-to-end).
