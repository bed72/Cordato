package com.bed.cordato.core.infrastructure.adapters

import java.time.Instant

import kotlin.test.Test
import kotlin.test.assertTrue

class ClockAdapterTest {

    private val clock = ClockAdapter()

    @Test
    fun `now returns an instant at or after the call time`() {
        val before = Instant.now()

        val now = clock()

        assertTrue(!now.isBefore(before))
    }
}
