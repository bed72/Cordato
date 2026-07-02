package com.bed.cordato.core.infrastructure.adapters

import java.time.Instant

import kotlin.test.Test
import kotlin.test.assertTrue

class ClockAdapterTest {

    @Test
    fun `now returns an instant at or after the call time`() {
        val before = Instant.now()

        val now = ClockAdapter().now()

        assertTrue(!now.isBefore(before))
    }
}
