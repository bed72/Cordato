package com.bed.cordato.features.expense.factories

import java.time.LocalDate

import com.bed.cordato.features.expense.application.driving.commands.CreateExpenseCommand

/**
 * Builds a [CreateExpenseCommand] from convenient defaults, mirroring identity's `signUpCommand`/`signInCommand`
 * — the command builder lives in `factories/`, never as a private helper inside the test class. The default
 * [date] is [EXPENSE_TODAY], the day the shared frozen clock ([EXPENSE_NOW]) falls on.
 */
fun createExpenseCommand(
    personId: String = "person-1",
    amountInCents: Long = 1_500,
    date: LocalDate? = EXPENSE_TODAY,
    description: String? = "Café",
): CreateExpenseCommand = CreateExpenseCommand(
    personId = personId,
    amountInCents = amountInCents,
    date = date,
    description = description,
)
