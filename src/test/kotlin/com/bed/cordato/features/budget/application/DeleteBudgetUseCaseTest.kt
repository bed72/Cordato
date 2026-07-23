package com.bed.cordato.features.budget.application

import kotlin.test.Test
import kotlin.test.assertIs
import kotlin.test.assertEquals

import com.bed.cordato.features.budget.factories.budget
import com.bed.cordato.features.budget.factories.deleteBudgetUseCase
import com.bed.cordato.features.budget.factories.deleteBudgetCommand
import com.bed.cordato.features.budget.factories.FakeBudgetRepository

import com.bed.cordato.features.budget.domain.enums.BudgetStatusEnum
import com.bed.cordato.features.budget.domain.errors.DeleteBudgetError

import com.bed.cordato.features.budget.application.driving.results.DeleteBudgetResult

internal class DeleteBudgetUseCaseTest {

    @Test
    fun `a live budget of the owner is removed`() {
        val repository = FakeBudgetRepository().apply { created.add(budget(id = "budget-1", personId = "person-1")) }

        val data = deleteBudgetUseCase(repository)(deleteBudgetCommand(budgetId = "budget-1", personId = "person-1"))

        val budget = assertIs<DeleteBudgetResult.Success>(data).budget
        assertEquals(BudgetStatusEnum.DELETED, budget.status)
        assertEquals(BudgetStatusEnum.DELETED, repository.findById("budget-1")?.status)
    }

    @Test
    fun `an unknown budget id is rejected as not found`() {
        val repository = FakeBudgetRepository()

        val data = deleteBudgetUseCase(repository)(deleteBudgetCommand(budgetId = "unknown"))

        assertEquals(DeleteBudgetError.BudgetNotFound, assertIs<DeleteBudgetResult.Failure>(data).error)
    }

    @Test
    fun `a budget of another person is rejected as not found`() {
        val repository = FakeBudgetRepository().apply { created.add(budget(id = "budget-1", personId = "person-2")) }

        val data = deleteBudgetUseCase(repository)(deleteBudgetCommand(budgetId = "budget-1", personId = "person-1"))

        assertEquals(BudgetStatusEnum.LIVE, repository.findById("budget-1")?.status)
        assertEquals(DeleteBudgetError.BudgetNotFound, assertIs<DeleteBudgetResult.Failure>(data).error)
    }

    @Test
    fun `an already removed budget is rejected as not found`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(id = "budget-1", personId = "person-1", status = BudgetStatusEnum.DELETED))
        }

        val data = deleteBudgetUseCase(repository)(deleteBudgetCommand(budgetId = "budget-1", personId = "person-1"))

        assertEquals(DeleteBudgetError.BudgetNotFound, assertIs<DeleteBudgetResult.Failure>(data).error)
    }
}
