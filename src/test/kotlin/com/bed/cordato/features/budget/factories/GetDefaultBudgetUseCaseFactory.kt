package com.bed.cordato.features.budget.factories

import com.bed.cordato.features.budget.application.driven.ports.ExpenseTotalSpentPort
import com.bed.cordato.features.budget.application.driven.ports.ExpenseSpentAmountPort
import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository
import com.bed.cordato.features.budget.application.driving.commands.GetDefaultBudgetCommand
import com.bed.cordato.features.budget.application.driving.use_cases.GetDefaultBudgetUseCase

/**
 * Builds a [GetDefaultBudgetUseCase] over deterministic collaborators, mirroring [getActiveBudgetUseCase]
 * — the SUT builder lives in `factories/`, never as a private helper inside the test class. [repository]
 * defaults to a fresh [FakeBudgetRepository]; [expenseTotalSpentPort]/[expenseSpentAmountPort] default to
 * ones that always answer `0`.
 */
fun getDefaultBudgetUseCase(
    repository: BudgetRepository = FakeBudgetRepository(),
    expenseTotalSpentPort: ExpenseTotalSpentPort = expenseTotalSpentPortOf(0),
    expenseSpentAmountPort: ExpenseSpentAmountPort = expenseSpentAmountPortOf(0),
): GetDefaultBudgetUseCase = GetDefaultBudgetUseCase(repository, expenseTotalSpentPort, expenseSpentAmountPort)

/** Convenience default so most tests only ever state the [personId] they care about. */
fun getDefaultBudgetCommand(personId: String = "person-1"): GetDefaultBudgetCommand = GetDefaultBudgetCommand(personId)
