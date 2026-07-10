package com.bed.cordato.features.expense.application.driving.commands

import java.time.LocalDate

/**
 * Raw register-expense input as it arrives from the outside world. The use case turns these into validated
 * value objects — validation is behavior, not the caller's job. [personId] is the owner, supplied by the
 * edge from the authenticated actor, **never** from the request body. [date] is optional (absent → today);
 * it is already a parsed [LocalDate] (a syntactically bad date was rejected as a `400` at the edge, before
 * here). [description] is optional and may be blank (the use case treats a null/blank one as absent).
 */
data class CreateExpenseCommand(
    val personId: String,
    val amountInCents: Long,
    val date: LocalDate?,
    val description: String?,
)
