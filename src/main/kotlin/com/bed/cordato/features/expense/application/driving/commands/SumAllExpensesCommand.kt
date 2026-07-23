package com.bed.cordato.features.expense.application.driving.commands

/**
 * Input for [com.bed.cordato.features.expense.application.driving.use_cases.SumAllExpensesUseCase]: the
 * total spent by [personId], with no date limit. This is the second (and last) input shape of expense's
 * public aggregate questions, answered to whoever is outside the context — today, `budget`'s own ACL, in
 * its own vocabulary.
 */
data class SumAllExpensesCommand(val personId: String)
