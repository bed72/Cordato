package com.bed.cordato.features.expense.factories

import com.bed.cordato.features.expense.application.driving.commands.SumAllExpensesCommand
import com.bed.cordato.features.expense.application.driving.use_cases.SumAllExpensesUseCase
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Builds a [SumAllExpensesUseCase] over a repository, mirroring [sumExpensesInRangeUseCase] — the SUT
 * builder lives in `factories/`, never as a private helper inside the test class. The [repository]
 * defaults to a fresh [FakeExpenseRepository]; a test that seeds rows passes its own instance.
 */
fun sumAllExpensesUseCase(
    repository: ExpenseRepository = FakeExpenseRepository(),
): SumAllExpensesUseCase = SumAllExpensesUseCase(repository)

/** Convenience default so most tests only ever state the [personId] they care about. */
fun sumAllExpensesCommand(personId: String = "person-1"): SumAllExpensesCommand = SumAllExpensesCommand(personId)
