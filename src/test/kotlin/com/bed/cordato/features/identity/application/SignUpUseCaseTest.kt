package com.bed.cordato.features.identity.application

import io.mockk.verify

import kotlin.test.Test
import kotlin.test.assertIs
import kotlin.test.assertTrue
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals

import com.bed.cordato.features.identity.application.results.SignUpResult
import com.bed.cordato.features.identity.application.commands.SignUpCommand
import com.bed.cordato.features.identity.application.use_cases.SignUpUseCase
import com.bed.cordato.features.identity.application.ports.PasswordHasherPort

import com.bed.cordato.features.identity.domain.errors.SignUpError
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject
import com.bed.cordato.features.identity.domain.value_objects.PasswordValueObject
import com.bed.cordato.features.identity.infrastructure.repositories.InMemoryPersonRepository

import com.bed.cordato.support.idGeneratorOf
import com.bed.cordato.support.passwordHasherMock


class SignUpUseCaseTest {

    private val validCommand = SignUpCommand(
        name = "Alice",
        password = "s3cretpw",
        email = "alice@example.com",
    )

    private fun useCase(
        id: String = "person-1",
        hasher: PasswordHasherPort = passwordHasherMock(),
        repository: InMemoryPersonRepository = InMemoryPersonRepository(),
    ) = SignUpUseCase(idGeneratorOf(id), hasher, repository) to hasher

    @Test
    fun `successful signup creates an active person stored only as a hash`() {
        val hasher = passwordHasherMock()
        val repository = InMemoryPersonRepository()
        val signUp = SignUpUseCase(idGeneratorOf("person-1"), hasher, repository)

        val data = signUp(validCommand)

        val success = assertIs<SignUpResult.Success>(data)
        val person = success.person

        verify { hasher.hash(any()) }
        assertEquals("person-1", person.id)
        assertNotEquals("s3cretpw", person.hash)
        assertEquals("bcrypt:s3cretpw", person.hash)
        assertEquals(PersonStatusEnum.ACTIVE, person.status)
        assertEquals(NameValueObject.of("Alice"), person.name)
        assertEquals(EmailValueObject.of("alice@example.com"), person.email)
        assertTrue(repository.existsByEmail(EmailValueObject.of("alice@example.com")!!))
    }

    @Test
    fun `e-mail already in use is rejected without hashing the password`() {
        val hasher = passwordHasherMock()
        val repository = InMemoryPersonRepository()
        SignUpUseCase(idGeneratorOf("person-1"), passwordHasherMock(), repository)(validCommand)

        val data = SignUpUseCase(idGeneratorOf("person-2"), hasher, repository)(validCommand)
        val failure = assertIs<SignUpResult.Failure>(data)

        assertEquals(SignUpError.EmailAlreadyInUse, failure.error)
        verify(exactly = 0) { hasher.hash(any()) } // uniqueness is checked before the expensive hashing
    }

    @Test
    fun `invalid e-mail is rejected and nothing is persisted or hashed`() {
        val (signUp, hasher) = useCase()

        val data = signUp(validCommand.copy(email = "not-an-email"))

        verify(exactly = 0) { hasher.hash(any()) }
        assertEquals(SignUpError.InvalidEmail, assertIs<SignUpResult.Failure>(data).error)
    }

    @Test
    fun `invalid name is rejected`() {
        val (signUp, _) = useCase()

        val data = signUp(validCommand.copy(name = "   "))

        assertEquals(SignUpError.InvalidName, assertIs<SignUpResult.Failure>(data).error)
    }

    @Test
    fun `weak password is rejected and reports the public minimum length`() {
        val (signUp, hasher) = useCase()

        val data = signUp(validCommand.copy(password = "short"))

        verify(exactly = 0) { hasher.hash(any()) }
        assertEquals(
            SignUpError.WeakPassword(PasswordValueObject.MIN_LENGTH),
            assertIs<SignUpResult.Failure>(data).error,
        )
    }

    @Test
    fun `result is handled exhaustively without any thrown domain error`() {
        val (signUp, _) = useCase()

        val label = when (val data = signUp(validCommand)) {
            is SignUpResult.Success -> "ok"
            is SignUpResult.Failure -> when (data.error) {
                SignUpError.InvalidName -> "invalid-name"
                SignUpError.InvalidEmail -> "invalid-email"
                is SignUpError.WeakPassword -> "weak-password"
                SignUpError.EmailAlreadyInUse -> "email-in-use"
            }
        }

        assertEquals("ok", label)
    }
}
