package com.bed.cordato.core.factories

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory
import io.micronaut.context.annotation.Replaces

import com.bed.cordato.core.application.driven.ports.LoggerPort

/**
 * Wires [FakeLoggerPort] in place of the real SLF4J-backed one for `@MicronautTest`, mirroring
 * [FakeSessionRepositoryFactory] — the `@Replaces` wiring of a test double lives in `factories/`,
 * never inline in a test class.
 */
@Factory
class FakeLoggerPortFactory {

    @Singleton
    @Replaces(LoggerPort::class)
    fun logger(): LoggerPort = FakeLoggerPort()
}
