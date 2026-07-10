package com.bed.cordato.features.expense.factories

import io.mockk.mockk

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory
import io.micronaut.context.annotation.Replaces

import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Replaces the persistence-backed [ExpenseRepository] with a mock for the `POST /expenses` e2e cover, so the
 * **real** `CreateExpenseUseCase` (which the factory builds from this bean) runs end-to-end without a
 * `DataSource` while the test observes/controls persistence. Mirrors identity's `PersonRepositoryMockFactory`
 * — the `@Replaces` wiring of a double lives in `factories/`, never inline in a test class.
 */
@Factory
class ExpenseRepositoryMockFactory {

    @Singleton
    @Replaces(ExpenseRepository::class)
    fun expenseRepository(): ExpenseRepository = mockk()
}
