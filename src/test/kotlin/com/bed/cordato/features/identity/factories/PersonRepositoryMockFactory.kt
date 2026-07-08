package com.bed.cordato.features.identity.factories

import io.mockk.mockk

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory
import io.micronaut.context.annotation.Replaces

import com.bed.cordato.features.identity.application.repositories.PersonRepository

/**
 * Replaces the persistence-backed [PersonRepository] with a mock for `@MicronautTest`, so the real
 * `MeUseCase` (which the factory builds from this bean) runs end-to-end without a `DataSource` while the
 * test controls what `findById` resolves per case. Mirrors `SignUpUseCaseMockFactory` — the `@Replaces`
 * wiring of a double lives in `factories/`, never inline in a test class.
 */
@Factory
class PersonRepositoryMockFactory {

    @Singleton
    @Replaces(PersonRepository::class)
    fun personRepository(): PersonRepository = mockk()
}
