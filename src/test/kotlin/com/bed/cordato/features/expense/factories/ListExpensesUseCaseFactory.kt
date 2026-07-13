package com.bed.cordato.features.expense.factories

import com.bed.cordato.features.expense.application.driving.use_cases.ListExpensesUseCase
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Builds a [ListExpensesUseCase] over a supplied [repository], mirroring [createExpenseUseCase] — the SUT
 * builder lives in `factories/`, never as a private helper inside the test class. The default is a fresh
 * [FakeExpenseRepository]; a test that seeds expenses passes its own instance.
 */
fun listExpensesUseCase(
    repository: ExpenseRepository = FakeExpenseRepository(),
): ListExpensesUseCase = ListExpensesUseCase(repository)
