package com.bed.cordato.features.budget.application.driving.commands

import java.time.LocalDate

/**
 * Raw create-budget input as it arrives from the outside world. The use case turns these into validated
 * value objects — validation is behavior, not the caller's job. [personId] is the owner, supplied by the
 * edge from the authenticated actor, **never** from the request body. [startDate]/[endDate] are already
 * parsed [LocalDate]s (a syntactically bad date was rejected as a `400` at the edge, before here); both are
 * required — there is no "today" default in this slice. [note] is optional and may be blank (the use case
 * treats a null/blank one as absent).
 */
data class CreateBudgetCommand(
    val personId: String,
    val amountInCents: Long,
    val startDate: LocalDate,
    val endDate: LocalDate,
    val note: String?,
)
