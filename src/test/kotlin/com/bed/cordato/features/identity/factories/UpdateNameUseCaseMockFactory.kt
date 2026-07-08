package com.bed.cordato.features.identity.factories

import io.mockk.mockk

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory
import io.micronaut.context.annotation.Replaces

import com.bed.cordato.features.identity.application.use_cases.UpdateNameUseCase

/**
 * Replaces the real [UpdateNameUseCase] with a mock for the `PATCH /persons/me` e2e cover, so the test can
 * drive each sealed outcome (success, `InvalidName`, `PersonNotFound`) through the edge guard, validation and
 * error contract without reaching persistence. Mirrors [SignUpUseCaseMockFactory]: the `@Replaces` wiring of
 * a double lives in `factories/`, never inline in a test class. This is the only way to exercise the `422`
 * domain-error mapping end-to-end, since the edge validation deliberately covers the same name rule.
 */
@Factory
class UpdateNameUseCaseMockFactory {

    @Singleton
    @Replaces(UpdateNameUseCase::class)
    fun updateNameUseCase(): UpdateNameUseCase = mockk()
}
