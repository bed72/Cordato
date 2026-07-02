package com.bed.cordato.core.infrastructure.adapters

import com.fasterxml.uuid.Generators

import com.bed.cordato.core.application.ports.IdGeneratorPort

/**
 * Real id generator backed by time-ordered UUID v7 (epoch-ms prefix + random). The
 * time ordering gives good index locality when the id is used as a database key. The
 * generator instance is thread-safe and reused across calls.
 */
class IdGeneratorAdapter : IdGeneratorPort {
    private val generator = Generators.timeBasedEpochGenerator()

    override fun invoke(): String = generator.generate().toString()
}
