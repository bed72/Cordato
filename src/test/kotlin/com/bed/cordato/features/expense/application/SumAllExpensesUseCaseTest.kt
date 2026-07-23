package com.bed.cordato.features.expense.application

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.assertEquals

import com.bed.cordato.features.expense.factories.expense
import com.bed.cordato.features.expense.factories.FakeExpenseRepository
import com.bed.cordato.features.expense.factories.sumAllExpensesCommand
import com.bed.cordato.features.expense.factories.sumAllExpensesUseCase

class SumAllExpensesUseCaseTest {

    @Test
    fun `sums all of the person's expenses regardless of date`() {
        val repository = FakeExpenseRepository()
        repository.create(expense(id = "a", personId = "person-1", amountInCents = 1_000, date = LocalDate.of(2026, 1, 5)))
        repository.create(expense(id = "b", personId = "person-1", amountInCents = 2_000, date = LocalDate.of(2026, 8, 1)))
        repository.create(expense(id = "c", personId = "person-2", amountInCents = 9_000, date = LocalDate.of(2026, 7, 10)))

        val total = sumAllExpensesUseCase(repository)(sumAllExpensesCommand(personId = "person-1"))

        assertEquals(3_000, total)
    }

    @Test
    fun `no expenses at all is zero, not an error`() {
        val repository = FakeExpenseRepository()

        val total = sumAllExpensesUseCase(repository)(sumAllExpensesCommand())

        assertEquals(0, total)
    }
}
