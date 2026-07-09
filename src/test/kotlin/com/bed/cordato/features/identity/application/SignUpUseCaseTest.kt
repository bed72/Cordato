package com.bed.cordato.features.identity.application

import io.mockk.verify

import kotlin.test.Test
import kotlin.test.assertIs
import kotlin.test.assertTrue
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals

import com.bed.cordato.features.identity.application.driving.results.SignUpResult
import com.bed.cordato.features.identity.application.driving.use_cases.SignUpUseCase

import com.bed.cordato.features.identity.domain.errors.SignUpError
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject
import com.bed.cordato.features.identity.domain.value_objects.PasswordValueObject

import com.bed.cordato.core.factories.idGeneratorOf

import com.bed.cordato.features.identity.factories.signUpCommand
import com.bed.cordato.features.identity.factories.signUpUseCase
import com.bed.cordato.features.identity.factories.passwordHasherMock
import com.bed.cordato.features.identity.factories.FakePersonRepository

class SignUpUseCaseTest {

    private val validCommand = signUpCommand()

    @Test
    fun `successful signup creates an active person stored only as a hash`() {
        val hasher = passwordHasherMock()
        val repository = FakePersonRepository()
        val signUp = SignUpUseCase(hasher, idGeneratorOf("person-1"), repository)

        val data = signUp(validCommand)

        val success = assertIs<SignUpResult.Success>(data)
        val person = success.person

        verify { hasher.create(any()) }
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
        val repository = FakePersonRepository()
        SignUpUseCase(passwordHasherMock(), idGeneratorOf("person-1"), repository)(validCommand)

        val data = SignUpUseCase(hasher, idGeneratorOf("person-2"), repository)(validCommand)
        val failure = assertIs<SignUpResult.Failure>(data)

        assertEquals(SignUpError.EmailAlreadyInUse, failure.error)
        verify(exactly = 0) { hasher.create(any()) }
    }

    @Test
    fun `invalid e-mail is rejected and nothing is persisted or hashed`() {
        val (signUp, hasher) = signUpUseCase()

        val data = signUp(validCommand.copy(email = "not-an-email"))

        verify(exactly = 0) { hasher.create(any()) }
        assertEquals(SignUpError.InvalidEmail, assertIs<SignUpResult.Failure>(data).error)
    }

    @Test
    fun `invalid name is rejected`() {
        val (signUp, _) = signUpUseCase()

        val data = signUp(validCommand.copy(name = "   "))

        assertEquals(SignUpError.InvalidName, assertIs<SignUpResult.Failure>(data).error)
    }

    @Test
    fun `weak password is rejected and reports the public minimum length`() {
        val (signUp, hasher) = signUpUseCase()

        val data = signUp(validCommand.copy(password = "short"))

        verify(exactly = 0) { hasher.create(any()) }
        assertEquals(
            SignUpError.WeakPassword(PasswordValueObject.MIN_LENGTH),
            assertIs<SignUpResult.Failure>(data).error,
        )
    }

    @Test
    fun `result is handled exhaustively without any thrown domain error`() {
        val (signUp, _) = signUpUseCase()

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
