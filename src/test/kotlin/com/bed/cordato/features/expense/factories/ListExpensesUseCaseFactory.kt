package com.bed.cordato.features.expense.factories

import com.bed.cordato.features.expense.domain.value_objects.ExpenseCursorValueObject
import com.bed.cordato.features.expense.application.driving.commands.ListExpensesCommand
import com.bed.cordato.features.expense.application.driving.use_cases.ListExpensesUseCase
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Builds a [ListExpensesUseCase] over a repository, mirroring [createExpenseUseCase] — the SUT builder lives
 * in `factories/`, never as a private helper inside the test class. The [repository] defaults to a fresh
 * [FakeExpenseRepository]; a test that seeds rows passes its own instance.
 */
fun listExpensesUseCase(
    repository: ExpenseRepository = FakeExpenseRepository(),
): ListExpensesUseCase = ListExpensesUseCase(repository)

/** Convenience default so most tests only ever state the [personId], [limit], or [after] they care about. */
fun listExpensesCommand(
    personId: String = "person-1",
    limit: Int = 20,
    after: ExpenseCursorValueObject? = null,
): ListExpensesCommand = ListExpensesCommand(personId, limit, after)
