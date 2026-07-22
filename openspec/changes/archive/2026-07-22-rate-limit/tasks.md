## 1. `cache-valkey`: expire primitive

- [x] 1.1 Add `fun expire(key: String, ttl: Duration)` to `core/application/driven/ports/CachePort.kt`,
      documented as `EXPIRE ... NX` semantics (arms a TTL only if the key has none; never touches the value).
- [x] 1.2 Implement it in `core/infrastructure/adapters/cache/CacheAdapter.kt` via Lettuce's expire command
      with the `NX` `ExpireArgs` option.
- [x] 1.3 Extend the test double `src/test/kotlin/com/bed/cordato/core/factories/FakeCachePort.kt` with the
      same primitive and semantics, so filter tests can run without a real Valkey.

## 2. Config

- [x] 2.1 Add `cordato.rate-limit.general.{limit,window}` and `cordato.rate-limit.sensitive.{limit,window}`
      to `src/main/resources/application.properties`, with sane defaults (see design.md's illustrative
      values — confirm final numbers before merging, per design.md's Open Questions).
- [x] 2.2 Add a `@ConfigurationProperties("cordato.rate-limit")` binding class (one config type, two nested
      tiers, or two sibling `@ConfigurationProperties`) in `core/infrastructure/http/rate_limit/`, mirroring
      how `DatabaseConfiguration`/`ValkeyConfiguration` bind external config today.

## 3. Tier annotation

- [x] 3.1 Add `RateLimitTierEnum` (`GENERAL`, `SENSITIVE`) as a domain-free edge enum in
      `core/infrastructure/http/rate_limit/annotations/` (or alongside the annotation type).
- [x] 3.2 Add the `@RateLimited(tier: RateLimitTierEnum = RateLimitTierEnum.SENSITIVE)` marker annotation in
      `core/infrastructure/http/rate_limit/annotations/`, mirroring
      `core/infrastructure/http/authentication/annotations/Authenticated.kt`'s shape and doc style.

## 4. Error response + i18n

- [x] 4.1 Add `ErrorItemResponse`/`ErrorsResponse` support for `429` — a `tooManyRequests(code, message,
      retryAfterSeconds)` builder in `core/infrastructure/http/responses/ErrorResponse.kt`, alongside
      `badRequest`/`unauthorized`/`unprocessable`/`internalError`, setting the `Retry-After` header.
- [x] 4.2 Add the new `RATE_LIMITED` message key to `src/main/resources/i18n/messages.properties` (and any
      other locale files present), following the existing scalar-message convention (ADR 0009).

## 5. The filter

- [x] 5.1 Add `RateLimitFilter` in `core/infrastructure/http/rate_limit/filters/`, `@ServerFilter
      (MATCH_ALL_PATTERN)`, `@Order` placed after `HttpRequestLoggingFilter`
      (`Ordered.HIGHEST_PRECEDENCE`) and before `AuthenticatedFilter`'s order value.
- [x] 5.2 In the `@RequestFilter` method: resolve the matched route via `RouteAttributes.getRouteMatch`
      (same accessor `AuthenticatedFilter` uses) to read the `@RateLimited` tier (default `GENERAL` when
      absent); compute `window_start` from `ClockPort`; build the `rate_limit:<tier>:<ip>:<window_start>`
      key from `request.remoteAddress`; `increment` via `CachePort`, then `expire` (unconditionally, relying
      on `NX`) with the tier's configured window duration.
- [x] 5.3 When the incremented count exceeds the tier's configured limit, return the `429` response built in
      task 4.1 directly from the `@RequestFilter` method (return-not-throw, mirroring how `AuthenticatedFilter`
      returns its `401` directly) — short-circuiting before the handler runs.
- [x] 5.4 Verify filter ordering end-to-end: a request to a route with `@Authenticated` but no/invalid token,
      once over the general-tier limit, gets `429` (not `401`) — i.e. rate limiting genuinely happens first.
      (Covered by `RateLimitFilterTest`'s ordering test, task 7.2.)

## 6. Annotate sensitive routes

- [x] 6.1 Add `@RateLimited(RateLimitTierEnum.SENSITIVE)` to the `sign-up` handler in identity's controller.
- [x] 6.2 Add it to the `sign-in` handler.
- [ ] 6.3 Add it to the couple invite-creation handler. **BLOCKED**: `couple` has no code yet (only
      `features/couple/README.md` — no controllers, use cases, or invite endpoint exist in this codebase).
      Deferred until couple's invite-creation handler is implemented by its own change; nothing to annotate
      today.

## 7. Tests

- [x] 7.1 Unit-test `CacheAdapter.expire`'s `NX` behavior against a real/embedded Valkey (or the existing
      integration harness `cache-valkey` already uses), covering: arming a TTL on a key with none, and a
      no-op on a key that already has one.
- [x] 7.2 Filter test (`RateLimitFilterTest`), following `AuthenticatedFilterTest`'s shape: `FakeCachePort` +
      `FakeClockPort` doubles, a `@Factory @Replaces` wiring in `core/factories/`, and the `support/`
      `AuthenticationProbeController` (or a new dedicated probe route) to drive requests through the real filter chain.
      Cover: under-limit passes through; over-limit returns `429` with the shared envelope shape and
      `Retry-After`; a fresh window resets the count; a `sensitive`-tier route uses its own, stricter budget
      independent of `general`; ordering versus `AuthenticatedFilter` (task 5.4's scenario) as an explicit
      test case.
- [x] 7.3 Extend `ArchitectureTest` (Konsist) if the new `rate_limit` package needs any new/adjusted layer
      rule coverage (it shouldn't, if it follows the existing `authentication`/`logging` package shape
      exactly — verify rather than assume).

## 8. Docs

- [x] 8.1 Add a new ADR (`docs/architecture/decisions/0015-http-rate-limiting.md`) capturing the settled
      decisions from `design.md` (fixed-window algorithm, IP-only keying in v1 and why, the `CachePort.expire`
      `NX` primitive, annotation-driven tiering), and add it to
      `docs/architecture/decisions/README.md`'s index — mirroring how ADR 0012 (edge auth) and ADR 0014
      (response envelope) document their respective cross-cutting filters.
- [ ] 8.2 Run `/opsx:sync` to fold the three delta specs into `openspec/specs/http-rate-limiting/spec.md`
      (new) and the `cache-valkey`/`http-error-handling` main specs (modified), then `/opsx:archive` once
      merged and verified.
