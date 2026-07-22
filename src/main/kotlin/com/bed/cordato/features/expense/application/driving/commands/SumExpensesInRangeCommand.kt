package com.bed.cordato.features.expense.application.driving.commands

import java.time.LocalDate

/**
 * Input for [com.bed.cordato.features.expense.application.driving.use_cases.SumExpensesInRangeUseCase]:
 * the total spent by [personId] within `[startDate, endDate]` (both included). This is the single input
 * shape of expense's one public aggregate question, answered to whoever is outside the context — today,
 * `budget`'s own ACL, in its own vocabulary.
 */
data class SumExpensesInRangeCommand(
    val personId: String,
    val startDate: LocalDate,
    val endDate: LocalDate,
)
