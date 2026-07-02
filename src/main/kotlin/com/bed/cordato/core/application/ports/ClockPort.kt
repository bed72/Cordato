package com.bed.cordato.core.application.ports

import java.time.Instant

/**
 * Determinism port: the current instant, injected rather than read from a global
 * so behavior stays testable with a frozen clock. Implemented in core/infrastructure.
 */
fun interface ClockPort {
    fun now(): Instant
}
