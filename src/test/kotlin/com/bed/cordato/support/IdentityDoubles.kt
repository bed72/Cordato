package com.bed.cordato.support

import io.mockk.every
import io.mockk.mockk

import com.bed.cordato.features.identity.application.ports.PasswordHasherPort
import com.bed.cordato.features.identity.application.repositories.PersonRepository
import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

/**
 * MockK double for [PasswordHasherPort]: stubs a deterministic, recognizable hash
 * so results are assertable, and — being a mock — lets tests `verify` whether the
 * (deliberately expensive) hashing was invoked or correctly skipped.
 *
 * `PasswordValueObject` is an inline `value class`, so at the JVM boundary MockK
 * hands the answer lambda the underlying `String` (which is exactly its `value`).
 */
fun passwordHasherMock(): PasswordHasherPort {
    val hasher = mockk<PasswordHasherPort>()
    every { hasher.create(any()) } answers { "bcrypt:${firstArg<String>()}" }
    return hasher
}

/**
 * Hand-written in-memory [PersonRepository] fake for pure use-case tests — fast, Docker-free,
 * and keyed by e-mail so uniqueness is cheap to answer. [signUp] honors the port's race-safe
 * contract (returns `false` when the e-mail is already present); the real durable behavior is
 * covered separately by the datastore adapter's Testcontainers tests.
 */
class FakePersonRepository : PersonRepository {
    private val byEmail = mutableMapOf<String, PersonEntity>()

    override fun existsByEmail(email: EmailValueObject): Boolean = byEmail.containsKey(email.value)

    override fun signUp(person: PersonEntity): Boolean =
        byEmail.putIfAbsent(person.email.value, person) == null

    // Mirrors the durable query: an unknown e-mail and a non-active person both collapse to null.
    override fun findByEmail(email: EmailValueObject): PersonEntity? =
        byEmail[email.value]?.takeIf { it.status == PersonStatusEnum.ACTIVE }
}
