package com.bed.cordato.features.identity.factories

import com.bed.cordato.core.factories.idGeneratorOf

import com.bed.cordato.features.identity.application.use_cases.SignUpUseCase
import com.bed.cordato.features.identity.application.ports.PasswordHasherPort
import com.bed.cordato.features.identity.application.repositories.PersonRepository

fun signUpUseCase(
    id: String = "person-1",
    hasher: PasswordHasherPort = passwordHasherMock(),
    repository: PersonRepository = FakePersonRepository(),
): Pair<SignUpUseCase, PasswordHasherPort> =
    SignUpUseCase(hasher, idGeneratorOf(id), repository) to hasher
