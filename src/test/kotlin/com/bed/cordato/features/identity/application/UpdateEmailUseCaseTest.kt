package com.bed.cordato.features.identity.application

import io.mockk.every
import io.mockk.mockk

import kotlin.test.Test
import kotlin.test.assertIs
import kotlin.test.assertEquals

import com.bed.cordato.features.identity.factories.person
import com.bed.cordato.features.identity.factories.passwordHasherMock
import com.bed.cordato.features.identity.factories.FakePersonRepository

import com.bed.cordato.features.identity.domain.errors.UpdateEmailError
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum

import com.bed.cordato.features.identity.application.driven.ports.PasswordHasherPort
import com.bed.cordato.features.identity.application.driving.results.UpdateEmailResult
import com.bed.cordato.features.identity.application.driving.commands.UpdateEmailCommand
import com.bed.cordato.features.identity.application.driven.repositories.PersonRepository
import com.bed.cordato.features.identity.application.driving.use_cases.UpdateEmailUseCase
import com.bed.cordato.features.identity.application.driven.outcomes.UpdateEmailOutcome

/**
 * Pure unit cover of [UpdateEmailUseCase] over the [FakePersonRepository] and a MockK [PasswordHasherPort]
 * whose `verify` is scripted per scenario. Confirms the step-up order (invalid e-mail → not found → password
 * → no-op → persist) and that no domain path throws. The write-race `PERSON_INACTIVE` outcome — a person that
 * goes non-active between the read and the write, which the stateful fake cannot reach — is driven with a
 * scripted [PersonRepository] mock.
 */
class UpdateEmailUseCaseTest {

    private fun useCase(
        repository: PersonRepository,
        hasher: PasswordHasherPort = passwordHasherMock(verifies = true),
    ): UpdateEmailUseCase = UpdateEmailUseCase(hasher, repository)

    private fun command(
        personId: String = "person-1",
        email: String = "new@example.com",
        password: String = "super-secret",
    ) = UpdateEmailCommand(personId = personId, email = email, password = password)

    @Test
    fun `a valid e-mail with the correct password updates and returns the updated public view`() {
        val stored = person(id = "person-1", rawEmail = "alice@example.com")
        val repository = FakePersonRepository().apply { signUp(stored) }

        val data = useCase(repository)(command(email = "new@example.com"))

        assertEquals("new@example.com", assertIs<UpdateEmailResult.Success>(data).person.email.value)
        assertEquals("new@example.com", repository.findById("person-1")!!.email.value)
    }

    @Test
    fun `only the e-mail changes — name, hash, status and id are untouched`() {
        val stored = person(id = "person-1", name = "Alice", hash = "bcrypt:secret", rawEmail = "alice@example.com")
        val repository = FakePersonRepository().apply { signUp(stored) }

        useCase(repository)(command(email = "new@example.com"))

        val persisted = repository.findById("person-1")!!
        assertEquals(stored.id, persisted.id)
        assertEquals(stored.hash, persisted.hash)
        assertEquals(stored.name, persisted.name)
        assertEquals(stored.status, persisted.status)
        assertEquals("new@example.com", persisted.email.value)
    }

    @Test
    fun `an e-mail rejected by the domain fails and persists nothing`() {
        val stored = person(id = "person-1", rawEmail = "alice@example.com")
        val repository = FakePersonRepository().apply { signUp(stored) }

        val data = useCase(repository)(command(email = "not-an-email"))

        assertEquals("alice@example.com", repository.findById("person-1")!!.email.value)
        assertEquals(UpdateEmailError.InvalidEmail, assertIs<UpdateEmailResult.Failure>(data).error)
    }

    @Test
    fun `an incorrect confirmation password fails as invalid credentials and persists nothing`() {
        val stored = person(id = "person-1", rawEmail = "alice@example.com")
        val repository = FakePersonRepository().apply { signUp(stored) }

        val data = useCase(repository, passwordHasherMock(verifies = false))(command(email = "new@example.com"))

        assertEquals("alice@example.com", repository.findById("person-1")!!.email.value)
        assertEquals(UpdateEmailError.InvalidCredentials, assertIs<UpdateEmailResult.Failure>(data).error)
    }

    @Test
    fun `an unknown id fails as person not found`() {
        val data = useCase(FakePersonRepository())(command(personId = "ghost"))

        assertEquals(UpdateEmailError.PersonNotFound, assertIs<UpdateEmailResult.Failure>(data).error)
    }

    @Test
    fun `a non-active person is indistinguishable from an unknown id`() {
        val stored = person(id = "person-1", rawEmail = "alice@example.com", status = PersonStatusEnum.DELETED)
        val repository = FakePersonRepository().apply { signUp(stored) }

        val data = useCase(repository)(command(email = "new@example.com"))

        assertEquals(UpdateEmailError.PersonNotFound, assertIs<UpdateEmailResult.Failure>(data).error)
    }

    @Test
    fun `a person that goes non-active between the read and the write fails as person not found`() {
        val stored = person(id = "person-1", rawEmail = "alice@example.com")
        val repository = mockk<PersonRepository> {
            every { findById("person-1") } returns stored
            every { updateEmail("person-1", any()) } returns UpdateEmailOutcome.PERSON_INACTIVE
        }

        val data = useCase(repository)(command(email = "new@example.com"))

        assertEquals(UpdateEmailError.PersonNotFound, assertIs<UpdateEmailResult.Failure>(data).error)
    }

    @Test
    fun `a new e-mail already held by another person fails as e-mail already in use`() {
        val alice = person(id = "person-1", rawEmail = "alice@example.com")
        val bob = person(id = "person-2", rawEmail = "bob@example.com")
        val repository = FakePersonRepository().apply { signUp(alice); signUp(bob) }

        val data = useCase(repository)(command(personId = "person-1", email = "bob@example.com"))

        assertEquals(UpdateEmailError.EmailAlreadyInUse, assertIs<UpdateEmailResult.Failure>(data).error)
        assertEquals("alice@example.com", repository.findById("person-1")!!.email.value)
    }

    @Test
    fun `changing to the person's own current e-mail is a successful no-op`() {
        val stored = person(id = "person-1", rawEmail = "alice@example.com")
        val repository = FakePersonRepository().apply { signUp(stored) }

        // A different casing normalizes to the same value, so it must not be treated as a conflict.
        val data = useCase(repository)(command(email = "ALICE@Example.com"))

        assertEquals("alice@example.com", assertIs<UpdateEmailResult.Success>(data).person.email.value)
        assertEquals("alice@example.com", repository.findById("person-1")!!.email.value)
    }
}
