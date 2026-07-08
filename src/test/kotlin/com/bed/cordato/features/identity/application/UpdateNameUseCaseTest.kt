package com.bed.cordato.features.identity.application

import kotlin.test.Test
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertEquals

import com.bed.cordato.features.identity.factories.email
import com.bed.cordato.features.identity.factories.person
import com.bed.cordato.features.identity.factories.FakePersonRepository

import com.bed.cordato.features.identity.domain.errors.UpdateNameError
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum

import com.bed.cordato.features.identity.application.results.UpdateNameResult
import com.bed.cordato.features.identity.application.commands.UpdateNameCommand
import com.bed.cordato.features.identity.application.use_cases.UpdateNameUseCase

class UpdateNameUseCaseTest {

    private fun updateNameUseCase(repository: FakePersonRepository): UpdateNameUseCase = UpdateNameUseCase(repository)

    @Test
    fun `a valid name updates and returns the updated public view`() {
        val stored = person(id = "person-1", name = "Alice")
        val repository = FakePersonRepository().apply { signUp(stored) }

        val data = updateNameUseCase(repository)(UpdateNameCommand(personId = "person-1", name = "Bob"))

        assertEquals("Bob", assertIs<UpdateNameResult.Success>(data).person.name.value)
        assertEquals("Bob", repository.findById("person-1")!!.name.value)
    }

    @Test
    fun `only the name changes — e-mail, hash, status and id are untouched`() {
        val stored = person(id = "person-1", name = "Alice", hash = "bcrypt:secret", rawEmail = "alice@example.com")
        val repository = FakePersonRepository().apply { signUp(stored) }

        updateNameUseCase(repository)(UpdateNameCommand(personId = "person-1", name = "Bob"))

        val persisted = repository.findById("person-1")!!
        assertEquals(stored.id, persisted.id)
        assertEquals(stored.hash, persisted.hash)
        assertEquals(stored.email, persisted.email)
        assertEquals(stored.status, persisted.status)
    }

    @Test
    fun `a name rejected by the domain fails and leaves the persisted name unchanged`() {
        val stored = person(id = "person-1", name = "Alice")
        val repository = FakePersonRepository().apply { signUp(stored) }

        val data = updateNameUseCase(repository)(UpdateNameCommand(personId = "person-1", name = "   "))

        assertEquals("Alice", repository.findById("person-1")!!.name.value)
        assertEquals(UpdateNameError.InvalidName, assertIs<UpdateNameResult.Failure>(data).error)
    }

    @Test
    fun `an unknown id fails as person not found`() {
        val data = updateNameUseCase(FakePersonRepository())(UpdateNameCommand(personId = "ghost", name = "Bob"))

        assertEquals(UpdateNameError.PersonNotFound, assertIs<UpdateNameResult.Failure>(data).error)
    }

    @Test
    fun `a non-active person is indistinguishable from an unknown id`() {
        val stored = person(id = "person-1", name = "Alice", status = PersonStatusEnum.DELETED)
        val repository = FakePersonRepository().apply { signUp(stored) }

        val data = updateNameUseCase(repository)(UpdateNameCommand(personId = "person-1", name = "Bob"))

        assertNull(repository.findByEmail(email("alice@example.com")))
        assertEquals(UpdateNameError.PersonNotFound, assertIs<UpdateNameResult.Failure>(data).error)
    }
}
