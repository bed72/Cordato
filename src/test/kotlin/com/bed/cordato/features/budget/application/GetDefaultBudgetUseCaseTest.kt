package com.bed.cordato.features.budget.application

import io.mockk.verify

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.assertEquals

import com.bed.cordato.features.budget.factories.budget
import com.bed.cordato.features.budget.factories.FakeBudgetRepository
import com.bed.cordato.features.budget.factories.getDefaultBudgetCommand
import com.bed.cordato.features.budget.factories.getDefaultBudgetUseCase
import com.bed.cordato.features.budget.factories.expenseTotalSpentPortOf
import com.bed.cordato.features.budget.factories.expenseSpentAmountPortOf

internal class GetDefaultBudgetUseCaseTest {

    @Test
    fun `without a live budget, the default spend is the entire total`() {
        val data = getDefaultBudgetUseCase(
            repository = FakeBudgetRepository(),
            expenseTotalSpentPort = expenseTotalSpentPortOf(50_000),
        )(getDefaultBudgetCommand(personId = "person-1"))

        assertEquals(50_000, data)
    }

    @Test
    fun `with one live budget covering part of the spend, only the remainder counts as default`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(id = "budget-1", personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 31)))
        }

        val data = getDefaultBudgetUseCase(
            repository = repository,
            expenseTotalSpentPort = expenseTotalSpentPortOf(50_000),
            expenseSpentAmountPort = expenseSpentAmountPortOf(30_000),
        )(getDefaultBudgetCommand(personId = "person-1"))

        assertEquals(20_000, data)
    }

    @Test
    fun `with multiple non-overlapping live budgets, each one's spend is subtracted from the total`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(id = "budget-1", personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 15)))
            created.add(budget(id = "budget-2", personId = "person-1", startDate = LocalDate.of(2026, 7, 16), endDate = LocalDate.of(2026, 7, 31)))
        }

        val data = getDefaultBudgetUseCase(
            repository = repository,
            expenseTotalSpentPort = expenseTotalSpentPortOf(100_000),
            expenseSpentAmountPort = expenseSpentAmountPortOf(20_000),
        )(getDefaultBudgetCommand(personId = "person-1"))

        assertEquals(60_000, data)
    }

    @Test
    fun `no expenses at all produces a zero default spend`() {
        val data = getDefaultBudgetUseCase(
            repository = FakeBudgetRepository(),
            expenseTotalSpentPort = expenseTotalSpentPortOf(0),
        )(getDefaultBudgetCommand(personId = "person-1"))

        assertEquals(0, data)
    }

    @Test
    fun `every expense covered by a live budget produces a zero default spend`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(id = "budget-1", personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 31)))
        }

        val data = getDefaultBudgetUseCase(
            repository = repository,
            expenseTotalSpentPort = expenseTotalSpentPortOf(50_000),
            expenseSpentAmountPort = expenseSpentAmountPortOf(50_000),
        )(getDefaultBudgetCommand(personId = "person-1"))

        assertEquals(0, data)
    }

    @Test
    fun `the spent amount is asked once per live budget, over its own period`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(id = "budget-1", personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 15)))
        }
        val port = expenseSpentAmountPortOf(0)

        getDefaultBudgetUseCase(
            repository = repository,
            expenseTotalSpentPort = expenseTotalSpentPortOf(0),
            expenseSpentAmountPort = port,
        )(getDefaultBudgetCommand(personId = "person-1"))

        verify(exactly = 1) { port("person-1", LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 15)) }
    }
}
