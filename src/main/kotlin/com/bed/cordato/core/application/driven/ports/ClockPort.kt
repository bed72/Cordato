package com.bed.cordato.core.application.driven.ports

import java.time.Instant

/**
 * Determinism port: the current instant, injected rather than read from a global
 * so behavior stays testable with a frozen clock. Implemented in core/infrastructure.
 */
fun interface ClockPort {
    operator fun invoke(): Instant
}
