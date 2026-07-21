package com.bed.cordato.features.budget.application

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.assertIs
import kotlin.test.assertTrue
import kotlin.test.assertNull
import kotlin.test.assertEquals

import com.bed.cordato.features.budget.factories.budget
import com.bed.cordato.features.budget.factories.createBudgetUseCase
import com.bed.cordato.features.budget.factories.createBudgetCommand
import com.bed.cordato.features.budget.factories.FakeBudgetRepository

import com.bed.cordato.features.budget.domain.enums.BudgetStatusEnum
import com.bed.cordato.features.budget.domain.errors.CreateBudgetError

import com.bed.cordato.features.budget.application.driving.results.CreateBudgetResult

internal class CreateBudgetUseCaseTest {

    @Test
    fun `a valid command creates and persists the budget`() {
        val repository = FakeBudgetRepository()

        val data = createBudgetUseCase(id = "budget-42", repository = repository)(createBudgetCommand())

        val budget = assertIs<CreateBudgetResult.Success>(data).budget
        assertEquals("budget-42", budget.id)
        assertEquals("person-1", budget.personId)
        assertEquals(100_000, budget.amount.cents)
        assertEquals("Viagem", budget.note!!.value)
        assertEquals(listOf(budget), repository.created)
        assertEquals(BudgetStatusEnum.LIVE, budget.status)
        assertEquals(LocalDate.of(2026, 7, 31), budget.period.endDate)
        assertEquals(LocalDate.of(2026, 7, 1), budget.period.startDate)
    }

    @Test
    fun `a non-positive amount is rejected and persists nothing`() {
        val repository = FakeBudgetRepository()

        val data = createBudgetUseCase(repository = repository)(createBudgetCommand(amountInCents = 0))

        assertTrue(repository.created.isEmpty())
        assertEquals(CreateBudgetError.InvalidAmount, assertIs<CreateBudgetResult.Failure>(data).error)
    }

    @Test
    fun `an end date before the start date is rejected and persists nothing`() {
        val repository = FakeBudgetRepository()

        val data = createBudgetUseCase(repository = repository)(
            createBudgetCommand(startDate = LocalDate.of(2026, 7, 15), endDate = LocalDate.of(2026, 7, 14)),
        )

        assertTrue(repository.created.isEmpty())
        assertEquals(CreateBudgetError.InvalidPeriod, assertIs<CreateBudgetResult.Failure>(data).error)
    }

    @Test
    fun `an over-length note is rejected and persists nothing`() {
        val repository = FakeBudgetRepository()
        val tooLong = "a".repeat(256)

        val data = createBudgetUseCase(repository = repository)(createBudgetCommand(note = tooLong))

        assertTrue(repository.created.isEmpty())
        assertEquals(CreateBudgetError.InvalidNote, assertIs<CreateBudgetResult.Failure>(data).error)
    }

    @Test
    fun `a blank note becomes an absent one`() {
        val data = createBudgetUseCase()(createBudgetCommand(note = "   "))

        assertNull(assertIs<CreateBudgetResult.Success>(data).budget.note)
    }

    @Test
    fun `a null note becomes an absent one`() {
        val data = createBudgetUseCase()(createBudgetCommand(note = null))

        assertNull(assertIs<CreateBudgetResult.Success>(data).budget.note)
    }

    @Test
    fun `the owner is the command's person, never a body-supplied id`() {
        val data = createBudgetUseCase()(createBudgetCommand(personId = "actor-owner"))

        assertEquals("actor-owner", assertIs<CreateBudgetResult.Success>(data).budget.personId)
    }

    @Test
    fun `a period overlapping another live budget of the same person is rejected and persists nothing`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 15)))
        }

        val data = createBudgetUseCase(repository = repository)(
            createBudgetCommand(personId = "person-1", startDate = LocalDate.of(2026, 7, 15), endDate = LocalDate.of(2026, 7, 31)),
        )

        assertEquals(1, repository.created.size)
        assertEquals(CreateBudgetError.OverlappingBudget, assertIs<CreateBudgetResult.Failure>(data).error)
    }

    @Test
    fun `an adjacent period, not overlapping, is accepted`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 15)))
        }

        val data = createBudgetUseCase(repository = repository)(
            createBudgetCommand(personId = "person-1", startDate = LocalDate.of(2026, 7, 16), endDate = LocalDate.of(2026, 7, 31)),
        )

        assertIs<CreateBudgetResult.Success>(data)
        assertEquals(2, repository.created.size)
    }

    @Test
    fun `a removed budget does not count towards the overlap check`() {
        val repository = FakeBudgetRepository().apply {
            created.add(
                budget(
                    personId = "person-1",
                    status = BudgetStatusEnum.DELETED,
                    endDate = LocalDate.of(2026, 7, 15),
                    startDate = LocalDate.of(2026, 7, 1),
                ),
            )
        }

        val data = createBudgetUseCase(repository = repository)(
            createBudgetCommand(personId = "person-1", startDate = LocalDate.of(2026, 7, 10), endDate = LocalDate.of(2026, 7, 20)),
        )

        assertIs<CreateBudgetResult.Success>(data)
    }
}
