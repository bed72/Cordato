package com.bed.cordato.features.budget.application.driving.commands

import java.time.LocalDate

/**
 * Raw edit-budget input as it arrives from the outside world. The use case turns these into validated value
 * objects — validation is behavior, not the caller's job. [budgetId] comes from the URL path, [personId]
 * from the authenticated actor, **never** from the request body — a person can only ever edit their own
 * budget. `amountInCents`/`startDate`/`endDate` are required, same shape as [CreateBudgetCommand]: this
 * slice always reedits the three mutable fields together, no partial edit of a single one. [note] is
 * optional and may be blank (the use case treats a null/blank one as absent).
 */
data class UpdateBudgetCommand(
    val budgetId: String,
    val personId: String,
    val amountInCents: Long,
    val startDate: LocalDate,
    val endDate: LocalDate,
    val note: String?,
)
