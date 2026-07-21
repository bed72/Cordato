package com.bed.cordato.features.budget.factories

import io.mockk.mockk

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory
import io.micronaut.context.annotation.Replaces

import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository

/**
 * Replaces the persistence-backed [BudgetRepository] with a mock for the `POST /budgets` e2e cover, so the
 * **real** `CreateBudgetUseCase` (which the factory builds from this bean) runs end-to-end without a
 * `DataSource` while the test observes/controls persistence. Mirrors expense's `ExpenseRepositoryMockFactory`
 * — the `@Replaces` wiring of a double lives in `factories/`, never inline in a test class.
 */
@Factory
class BudgetRepositoryMockFactory {

    @Singleton
    @Replaces(BudgetRepository::class)
    fun budgetRepository(): BudgetRepository = mockk()
}
