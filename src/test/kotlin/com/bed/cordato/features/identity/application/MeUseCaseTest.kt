package com.bed.cordato.features.identity.application

import kotlin.test.Test
import kotlin.test.assertIs
import kotlin.test.assertEquals

import com.bed.cordato.features.identity.domain.errors.MeError
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum

import com.bed.cordato.features.identity.application.driving.results.MeResult
import com.bed.cordato.features.identity.application.driving.commands.MeCommand
import com.bed.cordato.features.identity.application.driving.use_cases.MeUseCase

import com.bed.cordato.features.identity.factories.person
import com.bed.cordato.features.identity.factories.FakePersonRepository

class MeUseCaseTest {

    private fun meUseCase(repository: FakePersonRepository): MeUseCase = MeUseCase(repository)

    @Test
    fun `an active person resolves to a success carrying that person`() {
        val stored = person(id = "person-1")
        val repository = FakePersonRepository().apply { signUp(stored) }

        val data = meUseCase(repository)(MeCommand(personId = "person-1"))

        assertEquals(stored, assertIs<MeResult.Success>(data).person)
    }

    @Test
    fun `an unknown id fails as person not found`() {
        val data = meUseCase(FakePersonRepository())(MeCommand(personId = "ghost"))

        assertEquals(MeError.PersonNotFound, assertIs<MeResult.Failure>(data).error)
    }

    @Test
    fun `a non-active person is indistinguishable from an unknown id`() {
        val repository = FakePersonRepository().apply { signUp(person(id = "person-1", status = PersonStatusEnum.DELETED)) }

        val data = meUseCase(repository)(MeCommand(personId = "person-1"))

        assertEquals(MeError.PersonNotFound, assertIs<MeResult.Failure>(data).error)
    }
}
