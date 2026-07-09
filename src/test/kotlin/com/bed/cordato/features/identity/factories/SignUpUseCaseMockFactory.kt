package com.bed.cordato.features.identity.factories

import io.mockk.mockk

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory
import io.micronaut.context.annotation.Replaces

import com.bed.cordato.features.identity.application.driving.use_cases.SignUpUseCase
import com.bed.cordato.features.identity.application.driving.use_cases.SignInUseCase

@Factory
class SignUpUseCaseMockFactory {

    @Singleton
    @Replaces(SignUpUseCase::class)
    fun signUpUseCase(): SignUpUseCase = mockk()

    @Singleton
    @Replaces(SignInUseCase::class)
    fun signInUseCase(): SignInUseCase = mockk()
}
