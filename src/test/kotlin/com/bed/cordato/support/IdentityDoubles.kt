package com.bed.cordato.support

import io.mockk.every
import io.mockk.mockk

import com.bed.cordato.features.identity.application.ports.PasswordHasherPort

/**
 * MockK double for [PasswordHasherPort]: stubs a deterministic, recognizable hash
 * so results are assertable, and — being a mock — lets tests `verify` whether the
 * (deliberately expensive) hashing was invoked or correctly skipped.
 *
 * `PasswordValueObject` is an inline `value class`, so at the JVM boundary MockK
 * hands the answer lambda the underlying `String` (which is exactly its `value`).
 */
fun passwordHasherMock(): PasswordHasherPort = mockk {
    every { hash(any()) } answers { "bcrypt:${firstArg<String>()}" }
}
