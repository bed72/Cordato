package com.bed.cordato.features.identity.factories

import io.mockk.every
import io.mockk.mockk

import com.bed.cordato.features.identity.application.ports.PasswordHasherPort

fun passwordHasherMock(): PasswordHasherPort {
    val hasher = mockk<PasswordHasherPort>()
    every { hasher.create(any()) } answers { "bcrypt:${firstArg<String>()}" }
    return hasher
}
