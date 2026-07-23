package com.bed.cordato.features.budget.factories

import java.time.LocalDate

import com.bed.cordato.features.budget.application.driving.commands.UpdateBudgetCommand

/**
 * Builds an [UpdateBudgetCommand] from convenient defaults, mirroring `createBudgetCommand` — the command
 * builder lives in `factories/`, never as a private helper inside the test class.
 */
fun updateBudgetCommand(
    note: String? = "Viagem",
    budgetId: String = "budget-1",
    personId: String = "person-1",
    amountInCents: Long = 100_000,
    endDate: LocalDate = LocalDate.of(2026, 7, 31),
    startDate: LocalDate = LocalDate.of(2026, 7, 1),
): UpdateBudgetCommand = UpdateBudgetCommand(
    note = note,
    endDate = endDate,
    budgetId = budgetId,
    personId = personId,
    startDate = startDate,
    amountInCents = amountInCents,
)
