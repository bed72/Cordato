package com.bed.cordato.features.expense.factories

import java.time.LocalDate

import com.bed.cordato.features.expense.application.driving.commands.SumExpensesInRangeCommand
import com.bed.cordato.features.expense.application.driving.use_cases.SumExpensesInRangeUseCase
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Builds a [SumExpensesInRangeUseCase] over a repository, mirroring [listExpensesUseCase] — the SUT builder
 * lives in `factories/`, never as a private helper inside the test class. The [repository] defaults to a
 * fresh [FakeExpenseRepository]; a test that seeds rows passes its own instance.
 */
fun sumExpensesInRangeUseCase(
    repository: ExpenseRepository = FakeExpenseRepository(),
): SumExpensesInRangeUseCase = SumExpensesInRangeUseCase(repository)

/** Convenience default so most tests only ever state the [personId] or the range they care about. */
fun sumExpensesInRangeCommand(
    personId: String = "person-1",
    startDate: LocalDate = LocalDate.of(2026, 7, 1),
    endDate: LocalDate = LocalDate.of(2026, 7, 31),
): SumExpensesInRangeCommand = SumExpensesInRangeCommand(personId, startDate, endDate)
