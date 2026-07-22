package com.bed.cordato.core.factories

import java.time.Instant

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory
import io.micronaut.context.annotation.Replaces
import io.micronaut.context.annotation.Requires

import com.bed.cordato.core.application.driven.ports.ClockPort

/**
 * Wires [FakeClockPort] in place of the real one, but — unlike [FakeCachePortFactory]/
 * [FakeSessionRepositoryFactory] — **only** for `RateLimitFilterTest`
 * (`@Requires(property = "spec.name", value = "RateLimitFilterTest")`, the standard Micronaut Test idiom
 * for scoping a double to one spec — the counterpart `@Property(name = "spec.name", value =
 * "RateLimitFilterTest")` lives on the test class itself; `spec.name` is not set automatically).
 * `ClockPort` is a real dependency of other features (expense/budget date rules), unlike
 * `CachePort`/`SessionRepository`, which nothing outside the edge-auth guard consumes in a
 * `@MicronautTest` context — so a global replacement here would silently shift "today" for every other
 * controller test sharing the cached application context. The `spec.name` gate keeps this fake (and its
 * distinct property set) confined to its own, separately cached context.
 */
@Factory
@Requires(property = "spec.name", value = "RateLimitFilterTest")
class FakeClockPortFactory {

    @Singleton
    @Replaces(ClockPort::class)
    fun clock(): FakeClockPort = FakeClockPort(Instant.parse("2026-01-01T00:00:00Z"))
}
