package com.bed.cordato.features.identity.application

import io.mockk.every
import io.mockk.mockk

import kotlin.test.Test
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertEquals

import com.bed.cordato.core.factories.LIVE_SESSION_ID
import com.bed.cordato.core.factories.FakeSessionRepository

import com.bed.cordato.features.identity.factories.person
import com.bed.cordato.features.identity.factories.FakePersonRepository

import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum
import com.bed.cordato.features.identity.domain.errors.UpdatePasswordError

import com.bed.cordato.features.identity.application.driven.ports.PasswordHasherPort
import com.bed.cordato.features.identity.application.driving.results.UpdatePasswordResult
import com.bed.cordato.features.identity.application.driven.repositories.PersonRepository
import com.bed.cordato.features.identity.application.driving.commands.UpdatePasswordCommand
import com.bed.cordato.features.identity.application.driving.use_cases.UpdatePasswordUseCase

private const val NEW = "new-str0ng-secret"
private const val CURRENT = "current-secret"

/**
 * Pure unit cover of [UpdatePasswordUseCase] over the [FakePersonRepository], the [FakeSessionRepository] and
 * a MockK [PasswordHasherPort] whose two `verify` calls (current password, then new-vs-current) are scripted
 * per scenario. Confirms the step-up order (weak → not found → wrong current → same → persist → revoke), that
 * only the hash changes and the other sessions are revoked (the current one spared), that no failing path
 * writes or revokes, and that no domain path throws. The write-race `PersonNotFound` — a person that goes
 * non-active between the read and the write, which the stateful fake cannot reach — is driven with a scripted
 * [PersonRepository] mock.
 */
class UpdatePasswordUseCaseTest {

    // Scripts the two verify calls by argument: the current password matches (or not), and the new password
    // matches the stored hash only when it equals the current one. create echoes a recognizable hash.
    private fun hasher(currentMatches: Boolean = true, newMatchesCurrent: Boolean = false): PasswordHasherPort =
        mockk {
            every { verify(CURRENT, any()) } returns currentMatches
            every { verify(NEW, any()) } returns newMatchesCurrent
            every { create(any()) } answers { "bcrypt:${firstArg<Any>()}" }
        }

    private fun command(
        newPassword: String = NEW,
        personId: String = "person-1",
        currentPassword: String = CURRENT,
        sessionId: String = LIVE_SESSION_ID,
    ) = UpdatePasswordCommand(
        personId = personId,
        sessionId = sessionId,
        newPassword = newPassword,
        currentPassword = currentPassword,
    )

    @Test
    fun `a valid new password with the correct current password updates the hash and returns the public view`() {
        val sessions = FakeSessionRepository()
        val stored = person(id = "person-1", hash = "bcrypt:old")
        val repository = FakePersonRepository().apply { signUp(stored) }

        val data = UpdatePasswordUseCase(hasher(), repository, sessions)(command())

        assertEquals("bcrypt:$NEW", repository.findById("person-1")!!.hash)
        assertEquals("person-1", assertIs<UpdatePasswordResult.Success>(data).person.id)
    }

    @Test
    fun `only the hash changes — name, e-mail, status and id are untouched`() {
        val stored = person(id = "person-1", name = "Alice", rawEmail = "alice@example.com", hash = "bcrypt:old")
        val repository = FakePersonRepository().apply { signUp(stored) }

        UpdatePasswordUseCase(hasher(), repository, FakeSessionRepository())(command())

        val persisted = repository.findById("person-1")!!
        assertEquals(stored.id, persisted.id)
        assertEquals(stored.name, persisted.name)
        assertEquals(stored.email, persisted.email)
        assertEquals("bcrypt:$NEW", persisted.hash)
        assertEquals(stored.status, persisted.status)
    }

    @Test
    fun `a successful rotation revokes the other sessions and spares the current one`() {
        val sessions = FakeSessionRepository()
        val stored = person(id = "person-1", hash = "bcrypt:old")
        val repository = FakePersonRepository().apply { signUp(stored) }

        UpdatePasswordUseCase(hasher(), repository, sessions)(command(sessionId = LIVE_SESSION_ID))

        assertEquals("person-1", sessions.revokedForPerson)
        assertEquals(LIVE_SESSION_ID, sessions.sparedSessionId)
    }

    @Test
    fun `a new password rejected by the policy fails as weak and persists nothing, revoking nothing`() {
        val sessions = FakeSessionRepository()
        val stored = person(id = "person-1", hash = "bcrypt:old")
        val repository = FakePersonRepository().apply { signUp(stored) }

        val data = UpdatePasswordUseCase(hasher(), repository, sessions)(command(newPassword = "short"))

        assertNull(sessions.revokedForPerson)
        assertEquals("bcrypt:old", repository.findById("person-1")!!.hash)
        assertEquals(UpdatePasswordError.WeakPassword, assertIs<UpdatePasswordResult.Failure>(data).error)
    }

    @Test
    fun `an incorrect current password fails as invalid credentials and persists nothing, revoking nothing`() {
        val sessions = FakeSessionRepository()
        val stored = person(id = "person-1", hash = "bcrypt:old")
        val repository = FakePersonRepository().apply { signUp(stored) }

        val data = UpdatePasswordUseCase(hasher(currentMatches = false), repository, sessions)(command())

        assertNull(sessions.revokedForPerson)
        assertEquals("bcrypt:old", repository.findById("person-1")!!.hash)
        assertEquals(UpdatePasswordError.InvalidCredentials, assertIs<UpdatePasswordResult.Failure>(data).error)
    }

    @Test
    fun `a new password equal to the current one fails as same password and persists nothing, revoking nothing`() {
        val sessions = FakeSessionRepository()
        val stored = person(id = "person-1", hash = "bcrypt:old")
        val repository = FakePersonRepository().apply { signUp(stored) }

        val data = UpdatePasswordUseCase(hasher(newMatchesCurrent = true), repository, sessions)(command())

        assertNull(sessions.revokedForPerson)
        assertEquals("bcrypt:old", repository.findById("person-1")!!.hash)
        assertEquals(UpdatePasswordError.SamePassword, assertIs<UpdatePasswordResult.Failure>(data).error)
    }

    @Test
    fun `an unknown id fails as person not found`() {
        val sessions = FakeSessionRepository()

        val data = UpdatePasswordUseCase(hasher(), FakePersonRepository(), sessions)(command(personId = "ghost"))

        assertNull(sessions.revokedForPerson)
        assertEquals(UpdatePasswordError.PersonNotFound, assertIs<UpdatePasswordResult.Failure>(data).error)
    }

    @Test
    fun `a non-active person is indistinguishable from an unknown id`() {
        val sessions = FakeSessionRepository()
        val stored = person(id = "person-1", hash = "bcrypt:old", status = PersonStatusEnum.DELETED)
        val repository = FakePersonRepository().apply { signUp(stored) }

        val data = UpdatePasswordUseCase(hasher(), repository, sessions)(command())

        assertNull(sessions.revokedForPerson)
        assertEquals(UpdatePasswordError.PersonNotFound, assertIs<UpdatePasswordResult.Failure>(data).error)
    }

    @Test
    fun `a person that goes non-active between the read and the write fails as person not found, revoking nothing`() {
        val stored = person(id = "person-1", hash = "bcrypt:old")
        val repository = mockk<PersonRepository> {
            every { findById("person-1") } returns stored
            every { updatePassword("person-1", any()) } returns false
        }
        val sessions = FakeSessionRepository()
        val data = UpdatePasswordUseCase(hasher(), repository, sessions)(command())

        assertNull(sessions.revokedForPerson)
        assertEquals(UpdatePasswordError.PersonNotFound, assertIs<UpdatePasswordResult.Failure>(data).error)
    }
}
