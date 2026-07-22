package com.bed.cordato.features.budget.infrastructure.adapters

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.assertEquals

import com.bed.cordato.features.expense.factories.expense
import com.bed.cordato.features.expense.factories.FakeExpenseRepository
import com.bed.cordato.features.expense.factories.sumExpensesInRangeUseCase

/**
 * Covers the ACL translation (ADR 0013) with a **real** `SumExpensesInRangeUseCase` over a fake
 * `ExpenseRepository` — no mock of the use case itself — proving the adapter forwards budget's own
 * parameters and return value unchanged, through expense's own vocabulary.
 */
class ExpenseSpentAmountAdapterTest {

    @Test
    fun `forwards personId and the date range to expense's use case, returning its sum`() {
        val repository = FakeExpenseRepository()
        repository.create(expense(id = "a", personId = "person-1", amountInCents = 1_000, date = LocalDate.of(2026, 7, 10)))
        repository.create(expense(id = "b", personId = "person-1", amountInCents = 2_000, date = LocalDate.of(2026, 8, 1)))
        val adapter = ExpenseSpentAmountAdapter(sumExpensesInRangeUseCase(repository))

        val total = adapter("person-1", LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 31))

        assertEquals(1_000, total)
    }

    @Test
    fun `no expenses in range answers zero, not an error`() {
        val adapter = ExpenseSpentAmountAdapter(sumExpensesInRangeUseCase())

        val total = adapter("person-1", LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 31))

        assertEquals(0, total)
    }
}
