package com.bed.cordato.features.identity.factories

import io.mockk.mockk

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory
import io.micronaut.context.annotation.Replaces

import com.bed.cordato.features.identity.application.driving.use_cases.UpdatePasswordUseCase

/**
 * Replaces the real [UpdatePasswordUseCase] with a mock for the `PATCH /persons/me/password` e2e cover, so the
 * test can drive each sealed outcome (success, `WeakPassword`, `SamePassword`, `InvalidCredentials`,
 * `PersonNotFound`) through the edge guard, validation and error contract without reaching persistence.
 * Mirrors [UpdateEmailUseCaseMockFactory]: the `@Replaces` wiring of a double lives in `factories/`, never
 * inline in a test class. This is the only way to exercise the `422` domain-error mappings end-to-end, since
 * the edge validation deliberately covers the same minimum-length rule.
 */
@Factory
class UpdatePasswordUseCaseMockFactory {

    @Singleton
    @Replaces(UpdatePasswordUseCase::class)
    fun updatePasswordUseCase(): UpdatePasswordUseCase = mockk()
}
