package com.bed.cordato.features.identity.application

import io.mockk.slot
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify

import java.time.Instant

import kotlin.test.Test
import kotlin.test.assertIs
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

import com.bed.cordato.core.domain.entities.SessionEntity
import com.bed.cordato.core.application.driven.repositories.SessionRepository

import com.bed.cordato.core.factories.tokenizerOf
import com.bed.cordato.core.factories.clockFixedAt
import com.bed.cordato.core.factories.idGeneratorOf

import com.bed.cordato.features.identity.domain.errors.SignInError
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum

import com.bed.cordato.features.identity.application.driving.results.SignInResult
import com.bed.cordato.features.identity.application.driving.use_cases.SignInUseCase
import com.bed.cordato.features.identity.application.driven.ports.PasswordHasherPort
import com.bed.cordato.features.identity.application.driven.repositories.PersonRepository

import com.bed.cordato.features.identity.factories.person
import com.bed.cordato.features.identity.factories.signInCommand
import com.bed.cordato.features.identity.factories.passwordHasherMock
import com.bed.cordato.features.identity.factories.FakePersonRepository

class SignInUseCaseTest {

    private val now = Instant.parse("2026-07-07T12:00:00Z")
    private val command = signInCommand()

    private fun signInUseCase(
        hasher: PasswordHasherPort,
        repository: PersonRepository,
        sessionRepository: SessionRepository,
    ): SignInUseCase = SignInUseCase(
        clockFixedAt(now),
        tokenizerOf(token = "raw-token", hash = "hashed-token"),
        hasher,
        idGeneratorOf("session-1"),
        repository,
        sessionRepository,
    )

    @Test
    fun `successful sign-in opens a session and hands back the plaintext token once`() {
        val stored = person(hash = "bcrypt:super-secret")
        val repository = FakePersonRepository().apply { signUp(stored) }
        val hasher = passwordHasherMock(verifies = true)
        val sessionRepository = mockk<SessionRepository>()
        val opened = slot<SessionEntity>()
        every { sessionRepository.open(capture(opened)) } returns true

        val data = signInUseCase(hasher, repository, sessionRepository)(command)

        val success = assertIs<SignInResult.Success>(data)
        assertEquals("raw-token", success.token)
        assertEquals(opened.captured, success.session)
        assertEquals("session-1", success.session.id)
        assertEquals(stored.id, success.session.personId)
        assertEquals("hashed-token", success.session.hashToken)
        assertEquals(now, success.session.createdAt)
        assertEquals(now.plus(SessionEntity.TTL), success.session.expiresAt)
        verify { hasher.verify("s3cretpw", "bcrypt:super-secret") }
    }

    @Test
    fun `a wrong password is rejected as invalid credentials and opens no session`() {
        val repository = FakePersonRepository().apply { signUp(person()) }
        val hasher = passwordHasherMock(verifies = false)
        val sessionRepository = mockk<SessionRepository>()

        val data = signInUseCase(hasher, repository, sessionRepository)(command)

        assertEquals(SignInError.InvalidCredentials, assertIs<SignInResult.Failure>(data).error)
        verify(exactly = 0) { sessionRepository.open(any()) }
    }

    @Test
    fun `an unknown e-mail still pays one password verification and is rejected identically`() {
        val hasher = passwordHasherMock(verifies = false)
        val sessionRepository = mockk<SessionRepository>()

        val data = signInUseCase(hasher, FakePersonRepository(), sessionRepository)(command)

        assertEquals(SignInError.InvalidCredentials, assertIs<SignInResult.Failure>(data).error)
        verify(exactly = 1) { hasher.verify(any(), any()) }
        verify(exactly = 0) { sessionRepository.open(any()) }
    }

    @Test
    fun `a malformed e-mail is rejected identically and never reaches the repository`() {
        val hasher = passwordHasherMock(verifies = false)
        val repository = mockk<PersonRepository>()
        val sessionRepository = mockk<SessionRepository>()

        val data = signInUseCase(hasher, repository, sessionRepository)(command.copy(email = "not-an-email"))

        assertEquals(SignInError.InvalidCredentials, assertIs<SignInResult.Failure>(data).error)
        verify(exactly = 1) { hasher.verify(any(), any()) }
        verify(exactly = 0) { repository.findByEmail(any()) }
    }

    @Test
    fun `a non-active person is treated as unknown and never authenticates`() {
        val repository = FakePersonRepository().apply { signUp(person(status = PersonStatusEnum.DELETED)) }
        val hasher = passwordHasherMock(verifies = true)
        val sessionRepository = mockk<SessionRepository>()

        val data = signInUseCase(hasher, repository, sessionRepository)(command)

        assertEquals(SignInError.InvalidCredentials, assertIs<SignInResult.Failure>(data).error)
        verify(exactly = 0) { sessionRepository.open(any()) }
    }

    @Test
    fun `a failed session open surfaces as an infrastructure failure, not a credentials refusal`() {
        val repository = FakePersonRepository().apply { signUp(person()) }
        val hasher = passwordHasherMock(verifies = true)
        val sessionRepository = mockk<SessionRepository>()
        every { sessionRepository.open(any()) } returns false

        assertFailsWith<IllegalStateException> {
            signInUseCase(hasher, repository, sessionRepository)(command)
        }
    }
}
