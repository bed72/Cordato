package com.bed.cordato.features.budget.infrastructure.adapters

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.assertEquals

import com.bed.cordato.features.expense.factories.expense
import com.bed.cordato.features.expense.factories.FakeExpenseRepository
import com.bed.cordato.features.expense.factories.sumAllExpensesUseCase

/**
 * Covers the ACL translation (ADR 0013) with a **real** `SumAllExpensesUseCase` over a fake
 * `ExpenseRepository` — no mock of the use case itself — proving the adapter forwards budget's own
 * parameter and return value unchanged, through expense's own vocabulary. Mirrors
 * `ExpenseSpentAmountAdapterTest`.
 */
class ExpenseTotalSpentAdapterTest {

    @Test
    fun `forwards personId to expense's use case, returning its total sum`() {
        val repository = FakeExpenseRepository()
        repository.create(expense(id = "a", personId = "person-1", amountInCents = 1_000, date = LocalDate.of(2026, 1, 10)))
        repository.create(expense(id = "b", personId = "person-1", amountInCents = 2_000, date = LocalDate.of(2026, 8, 1)))
        repository.create(expense(id = "c", personId = "person-2", amountInCents = 9_000, date = LocalDate.of(2026, 7, 15)))
        val adapter = ExpenseTotalSpentAdapter(sumAllExpensesUseCase(repository))

        val total = adapter("person-1")

        assertEquals(3_000, total)
    }

    @Test
    fun `no expenses at all answers zero, not an error`() {
        val adapter = ExpenseTotalSpentAdapter(sumAllExpensesUseCase())

        val total = adapter("person-1")

        assertEquals(0, total)
    }
}
