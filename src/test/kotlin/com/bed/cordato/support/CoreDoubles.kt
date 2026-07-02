package com.bed.cordato.support

import io.mockk.every
import io.mockk.mockk
import java.time.Instant

import com.bed.cordato.core.application.ports.ClockPort
import com.bed.cordato.core.application.ports.IdGeneratorPort

/**
 * MockK-based test doubles for the core determinism ports, kept out of the test
 * classes so setup is declared once and reused. Stateful collaborators (e.g. the
 * in-memory repository) stay real fakes; these ports are pure stubs.
 */

/** [ClockPort] frozen at [instant], so time-dependent behavior is deterministic. */
fun clockFixedAt(instant: Instant): ClockPort = mockk {
    every { now() } returns instant
}

/** [IdGeneratorPort] that hands out [ids] in order across successive calls. */
fun idGeneratorOf(vararg ids: String): IdGeneratorPort {
    val generator = mockk<IdGeneratorPort>()
    every { generator() } returnsMany ids.toList()
    return generator
}
