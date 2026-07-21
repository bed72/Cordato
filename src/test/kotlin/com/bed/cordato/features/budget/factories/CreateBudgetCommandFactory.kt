package com.bed.cordato.features.budget.factories

import java.time.LocalDate

import com.bed.cordato.features.budget.application.driving.commands.CreateBudgetCommand

/**
 * Builds a [CreateBudgetCommand] from convenient defaults, mirroring expense's `createExpenseCommand` — the
 * command builder lives in `factories/`, never as a private helper inside the test class.
 */
fun createBudgetCommand(
    personId: String = "person-1",
    amountInCents: Long = 100_000,
    endDate: LocalDate = LocalDate.of(2026, 7, 31),
    startDate: LocalDate = LocalDate.of(2026, 7, 1),
    note: String? = "Viagem",
): CreateBudgetCommand = CreateBudgetCommand(
    note = note,
    endDate = endDate,
    personId = personId,
    startDate = startDate,
    amountInCents = amountInCents,
)
