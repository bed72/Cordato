package com.bed.cordato.features.identity.factories

import io.mockk.every
import io.mockk.mockk

import com.bed.cordato.features.identity.application.ports.PasswordHasherPort

fun passwordHasherMock(verifies: Boolean = false): PasswordHasherPort {
    val hasher = mockk<PasswordHasherPort>()
    every { hasher.create(any()) } answers { "bcrypt:${firstArg<String>()}" }
    every { hasher.verify(any(), any()) } returns verifies
    return hasher
}
