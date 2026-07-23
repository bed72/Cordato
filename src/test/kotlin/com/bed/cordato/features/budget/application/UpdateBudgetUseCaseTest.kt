package com.bed.cordato.features.budget.application

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertEquals

import com.bed.cordato.features.budget.factories.budget
import com.bed.cordato.features.budget.factories.updateBudgetUseCase
import com.bed.cordato.features.budget.factories.updateBudgetCommand
import com.bed.cordato.features.budget.factories.FakeBudgetRepository

import com.bed.cordato.features.budget.domain.enums.BudgetStatusEnum
import com.bed.cordato.features.budget.domain.errors.UpdateBudgetError

import com.bed.cordato.features.budget.application.driving.results.UpdateBudgetResult

internal class UpdateBudgetUseCaseTest {

    @Test
    fun `a valid command updates and persists the budget`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(id = "budget-1", personId = "person-1", amountInCents = 10_000))
        }

        val data = updateBudgetUseCase(repository)(
            updateBudgetCommand(
                note = "Editada",
                budgetId = "budget-1",
                personId = "person-1",
                amountInCents = 50_000,
                endDate = LocalDate.of(2026, 8, 10),
                startDate = LocalDate.of(2026, 8, 1),
            ),
        )

        val budget = assertIs<UpdateBudgetResult.Success>(data).budget
        assertEquals("budget-1", budget.id)
        assertEquals(50_000, budget.amount.cents)
        assertEquals("Editada", budget.note!!.value)
        assertEquals(budget, repository.findById("budget-1"))
        assertEquals(LocalDate.of(2026, 8, 1), budget.period.startDate)
        assertEquals(LocalDate.of(2026, 8, 10), budget.period.endDate)
    }

    @Test
    fun `a non-positive amount is rejected and persists nothing`() {
        val repository = FakeBudgetRepository().apply { created.add(budget(id = "budget-1", personId = "person-1")) }

        val data = updateBudgetUseCase(repository)(updateBudgetCommand(amountInCents = 0))

        assertEquals(100_000, repository.findById("budget-1")?.amount?.cents)
        assertEquals(UpdateBudgetError.InvalidAmount, assertIs<UpdateBudgetResult.Failure>(data).error)
    }

    @Test
    fun `an end date before the start date is rejected and persists nothing`() {
        val repository = FakeBudgetRepository().apply { created.add(budget(id = "budget-1", personId = "person-1")) }

        val data = updateBudgetUseCase(repository)(
            updateBudgetCommand(startDate = LocalDate.of(2026, 7, 15), endDate = LocalDate.of(2026, 7, 14)),
        )

        assertEquals(UpdateBudgetError.InvalidPeriod, assertIs<UpdateBudgetResult.Failure>(data).error)
    }

    @Test
    fun `an over-length note is rejected and persists nothing`() {
        val repository = FakeBudgetRepository().apply { created.add(budget(id = "budget-1", personId = "person-1")) }
        val tooLong = "a".repeat(256)

        val data = updateBudgetUseCase(repository)(updateBudgetCommand(note = tooLong))

        assertEquals(UpdateBudgetError.InvalidNote, assertIs<UpdateBudgetResult.Failure>(data).error)
    }

    @Test
    fun `a blank note becomes an absent one`() {
        val repository = FakeBudgetRepository().apply { created.add(budget(id = "budget-1", personId = "person-1")) }

        val data = updateBudgetUseCase(repository)(updateBudgetCommand(note = "   "))

        assertNull(assertIs<UpdateBudgetResult.Success>(data).budget.note)
    }

    @Test
    fun `an unknown budget id is rejected as not found`() {
        val repository = FakeBudgetRepository()

        val data = updateBudgetUseCase(repository)(updateBudgetCommand(budgetId = "unknown"))

        assertEquals(UpdateBudgetError.BudgetNotFound, assertIs<UpdateBudgetResult.Failure>(data).error)
    }

    @Test
    fun `a budget of another person is rejected as not found`() {
        val repository = FakeBudgetRepository().apply { created.add(budget(id = "budget-1", personId = "person-2")) }

        val data = updateBudgetUseCase(repository)(updateBudgetCommand(budgetId = "budget-1", personId = "person-1"))

        assertEquals(UpdateBudgetError.BudgetNotFound, assertIs<UpdateBudgetResult.Failure>(data).error)
    }

    @Test
    fun `an already removed budget is rejected as not found`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(id = "budget-1", personId = "person-1", status = BudgetStatusEnum.DELETED))
        }

        val data = updateBudgetUseCase(repository)(updateBudgetCommand(budgetId = "budget-1", personId = "person-1"))

        assertEquals(UpdateBudgetError.BudgetNotFound, assertIs<UpdateBudgetResult.Failure>(data).error)
    }

    @Test
    fun `an overlap with another live budget of the same person is rejected and persists nothing`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(id = "budget-1", personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 15)))
            created.add(budget(id = "budget-2", personId = "person-1", startDate = LocalDate.of(2026, 8, 1), endDate = LocalDate.of(2026, 8, 15)))
        }

        val data = updateBudgetUseCase(repository)(
            updateBudgetCommand(
                budgetId = "budget-2",
                personId = "person-1",
                endDate = LocalDate.of(2026, 7, 20),
                startDate = LocalDate.of(2026, 7, 10),
            ),
        )

        assertEquals(LocalDate.of(2026, 8, 1), repository.findById("budget-2")?.period?.startDate)
        assertEquals(UpdateBudgetError.OverlappingBudget, assertIs<UpdateBudgetResult.Failure>(data).error)
    }

    @Test
    fun `editing a budget without changing its period does not conflict with itself`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(id = "budget-1", personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 15)))
        }

        val data = updateBudgetUseCase(repository)(
            updateBudgetCommand(
                budgetId = "budget-1",
                personId = "person-1",
                endDate = LocalDate.of(2026, 7, 15),
                startDate = LocalDate.of(2026, 7, 1),
            ),
        )

        assertIs<UpdateBudgetResult.Success>(data)
    }

    @Test
    fun `the owner never changes even if the command tries`() {
        val repository = FakeBudgetRepository().apply { created.add(budget(id = "budget-1", personId = "person-1")) }

        val data = updateBudgetUseCase(repository)(updateBudgetCommand(budgetId = "budget-1", personId = "person-1"))

        assertEquals("person-1", assertIs<UpdateBudgetResult.Success>(data).budget.personId)
    }
}
