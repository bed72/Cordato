## Why

The app has no centralized logging: the only existing log call
(`UnexpectedFailureExceptionHandler`) invokes `org.slf4j.LoggerFactory` directly, and no SLF4J
binding is declared in the build — so that call silently falls through to the no-op logger today.
There is also no shared way for `application/` use cases to log without importing a concrete
logging library, which the layer table forbids. We need a `core` port/adapter pair now, designed
so a future OpenTelemetry Logs/traces integration is an adapter swap, not a call-site rewrite.

## What Changes

- Add `LoggerPort` (core, `application/driven/ports/`) — a multi-method port (`debug`/`info`/`warn`/`error`),
  taking a `component` name per call, structured `attributes` restricted to a `LoggableValueObject` type
  (`String`/`Number`/`Boolean`/`Instant`) so a whole entity/value object can't be logged by accident,
  and an optional `cause` on `error`.
- Add `Slf4jLoggerAdapter` (core, `infrastructure/adapters/`) implementing `LoggerPort` over SLF4J,
  including a fixed denylist of sensitive attribute keys (`password`, `token`, `email`,
  `authorization`, ...) that are masked/hashed before emission — a defense-in-depth net independent
  of the `LoggableValueObject` type restriction.
- Add a real SLF4J binding (`logback-classic`) to the build — none exists today, so the only
  existing log call is currently a no-op.
- Wire `LoggerPort` in `CoreFactory`.
- Migrate the existing ad-hoc `LoggerFactory.getLogger(...)` call in
  `UnexpectedFailureExceptionHandler` to `LoggerPort`, and replace the `println(...)` in `Main.kt`'s
  startup message with a `LoggerPort` call — these are the two loose logging call sites in the
  codebase today and must not remain outside the new port.
- Add a cross-cutting HTTP request/response logging filter (mirrors `AuthenticatedFilter`'s
  `@ServerFilter(ServerFilter.MATCH_ALL_PATTERN)` shape): logs method/path/status/duration for
  every request via `LoggerPort`, and mints a per-request correlation id propagated through MDC —
  the same MDC key a future OTEL trace id will occupy, so no call site changes when tracing lands.
- Extend the existing Konsist `ArchitectureTest` (which already bans persistence/DI-library imports
  in `domain/`+`application/`) to also ban `org.slf4j` there — the same shape as the existing rules,
  so "no direct SLF4J outside the port" is enforced, not just a convention.

Explicitly out of scope: a `MetricsPort` and any real OpenTelemetry wiring (traces, metric
exporters, Collector). Noted as future work in `design.md`.

## Capabilities

### New Capabilities

- `structured-logging`: the `LoggerPort`/`LoggableValueObject`/`Slf4jLoggerAdapter` kernel — structured,
  attribute-based logging with built-in sensitive-data redaction, wired in `core`, consumed by
  every layer above `domain/`.
- `http-request-logging`: the cross-cutting request/response log filter and per-request
  correlation id, built on top of `structured-logging`.

### Modified Capabilities

(none — no existing spec's requirements change; this only adds new behavior)

## Impact

- **New code**: `core/application/driven/ports/LoggerPort.kt`, a `LoggableValueObject` type,
  `core/infrastructure/adapters/Slf4jLoggerAdapter.kt`, a request-logging `@ServerFilter` under
  `core/infrastructure/http/`, `CoreFactory` wiring.
- **Changed code**: `UnexpectedFailureExceptionHandler` (migrate its log call),
  `main/Main.kt` (replace `println` with `LoggerPort`).
- **Build**: `build.gradle.kts` gains a `logback-classic` runtime dependency (currently only
  `slf4j-api` is on the classpath, transitively, with no binding).
- **No HTTP contract change**: this is operator-facing only: no response body, status code, or
  OpenAPI doc changes.
