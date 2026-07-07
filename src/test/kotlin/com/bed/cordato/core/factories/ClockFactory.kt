package com.bed.cordato.core.factories

import io.mockk.every
import io.mockk.mockk

import java.time.Instant

import com.bed.cordato.core.application.ports.ClockPort

fun clockFixedAt(instant: Instant): ClockPort {
    val clock = mockk<ClockPort>()
    every { clock() } returns instant
    return clock
}
