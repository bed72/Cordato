package com.bed.cordato.core.factories

import java.time.Instant

import com.bed.cordato.core.application.driven.ports.ClockPort

/**
 * Mutable [ClockPort] fake for tests that need to observe behavior across a time boundary (e.g.
 * `RateLimitFilterTest`'s "a fresh window resets the count") without sleeping real wall-clock time.
 * [clockFixedAt] (also in this package) covers the far more common single-instant case via a `mockk`;
 * this one exists only for the rarer case of advancing time mid-test.
 */
class FakeClockPort(private var instant: Instant) : ClockPort {
    override fun invoke(): Instant = instant

    fun advanceTo(instant: Instant) {
        this.instant = instant
    }
}
