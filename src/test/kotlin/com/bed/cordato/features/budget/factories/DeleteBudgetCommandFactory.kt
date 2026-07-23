package com.bed.cordato.features.budget.factories

import com.bed.cordato.features.budget.application.driving.commands.DeleteBudgetCommand

/**
 * Builds a [DeleteBudgetCommand] from convenient defaults, mirroring `createBudgetCommand` — the command
 * builder lives in `factories/`, never as a private helper inside the test class.
 */
fun deleteBudgetCommand(
    budgetId: String = "budget-1",
    personId: String = "person-1",
): DeleteBudgetCommand = DeleteBudgetCommand(budgetId = budgetId, personId = personId)
