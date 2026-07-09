package com.bed.cordato.features.identity.factories

import io.mockk.mockk

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory
import io.micronaut.context.annotation.Replaces

import com.bed.cordato.features.identity.application.driving.use_cases.UpdateEmailUseCase

/**
 * Replaces the real [UpdateEmailUseCase] with a mock for the `PATCH /persons/me/email` e2e cover, so the test
 * can drive each sealed outcome (success, `InvalidEmail`, `EmailAlreadyInUse`, `InvalidCredentials`,
 * `PersonNotFound`) through the edge guard, validation and error contract without reaching persistence.
 * Mirrors [UpdateNameUseCaseMockFactory]: the `@Replaces` wiring of a double lives in `factories/`, never
 * inline in a test class. This is the only way to exercise the `422` domain-error mappings end-to-end, since
 * the edge validation deliberately covers the same e-mail format rule.
 */
@Factory
class UpdateEmailUseCaseMockFactory {

    @Singleton
    @Replaces(UpdateEmailUseCase::class)
    fun updateEmailUseCase(): UpdateEmailUseCase = mockk()
}
