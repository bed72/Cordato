package com.bed.cordato.core.factories

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory
import io.micronaut.context.annotation.Replaces

import com.bed.cordato.core.application.driven.ports.CachePort

/**
 * Wires [FakeCachePort] in place of the Valkey-backed one for every `@MicronautTest`, so no test context
 * ever needs a reachable Valkey just because some bean happens to depend on [CachePort]. Mirrors
 * [FakeSessionRepositoryFactory] — the `@Replaces` wiring of a test double lives in `factories/`, never
 * inline in a test class.
 */
@Factory
class FakeCachePortFactory {

    @Singleton
    @Replaces(CachePort::class)
    fun cachePort(): CachePort = FakeCachePort()
}
