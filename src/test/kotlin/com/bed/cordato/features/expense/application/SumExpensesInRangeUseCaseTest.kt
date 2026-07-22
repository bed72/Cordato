package com.bed.cordato.features.expense.application

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.assertEquals

import com.bed.cordato.features.expense.factories.expense
import com.bed.cordato.features.expense.factories.FakeExpenseRepository
import com.bed.cordato.features.expense.factories.sumExpensesInRangeCommand
import com.bed.cordato.features.expense.factories.sumExpensesInRangeUseCase

class SumExpensesInRangeUseCaseTest {

    @Test
    fun `sums only the person's expenses whose date falls within the range`() {
        val repository = FakeExpenseRepository()
        repository.create(expense(id = "a", personId = "person-1", amountInCents = 1_000, date = LocalDate.of(2026, 7, 5)))
        repository.create(expense(id = "b", personId = "person-1", amountInCents = 2_000, date = LocalDate.of(2026, 7, 15)))
        repository.create(expense(id = "c", personId = "person-1", amountInCents = 5_000, date = LocalDate.of(2026, 8, 1)))
        repository.create(expense(id = "d", personId = "person-2", amountInCents = 9_000, date = LocalDate.of(2026, 7, 10)))

        val total = sumExpensesInRangeUseCase(repository)(sumExpensesInRangeCommand(personId = "person-1"))

        assertEquals(3_000, total)
    }

    @Test
    fun `boundary dates are included`() {
        val repository = FakeExpenseRepository()
        repository.create(expense(id = "a", personId = "person-1", amountInCents = 100, date = LocalDate.of(2026, 7, 1)))
        repository.create(expense(id = "b", personId = "person-1", amountInCents = 200, date = LocalDate.of(2026, 7, 31)))

        val total = sumExpensesInRangeUseCase(repository)(
            sumExpensesInRangeCommand(personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 31)),
        )

        assertEquals(300, total)
    }

    @Test
    fun `no expenses in range is zero, not an error`() {
        val repository = FakeExpenseRepository()

        val total = sumExpensesInRangeUseCase(repository)(sumExpensesInRangeCommand())

        assertEquals(0, total)
    }
}
