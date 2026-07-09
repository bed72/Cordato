package com.bed.cordato.core.factories

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory
import io.micronaut.context.annotation.Replaces

import com.bed.cordato.core.application.driven.repositories.SessionRepository

/**
 * Wires [FakeSessionRepository] in place of the persistence-backed one for `@MicronautTest`, so the
 * edge-auth guard resolves sessions without realizing a `DataSource`. Mirrors identity's
 * `SignUpUseCaseMockFactory` — the `@Replaces` wiring of a test double lives in `factories/`, never
 * inline in a test class.
 */
@Factory
class FakeSessionRepositoryFactory {

    @Singleton
    @Replaces(SessionRepository::class)
    fun sessionRepository(): SessionRepository = FakeSessionRepository()
}
