package com.bed.cordato.core.infrastructure.adapters

import java.time.Instant

import com.bed.cordato.core.application.ports.ClockPort

/** Real clock backed by the system UTC time source. */
class ClockAdapter : ClockPort {
    override operator fun invoke(): Instant = Instant.now()
}
