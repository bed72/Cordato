package com.bed.cordato.features.expense.infrastructure.http.mappers.requests

import com.bed.cordato.features.expense.application.driving.commands.CreateExpenseCommand
import com.bed.cordato.features.expense.infrastructure.http.requests.CreateExpenseRequest

/**
 * Builds the application's [CreateExpenseCommand] from the [CreateExpenseRequest] body and the authenticated
 * actor's `personId`, as an `internal` extension so the call site reads `request.toCommand(actor.personId)`.
 * The owner comes from the actor the edge guard resolved, never from the body — a person can only register
 * their own expense. `amountInCents` is non-null here: edge `@NotNull` validation already ran and threw a
 * `400` before this mapper, so `!!` cannot fail. The remaining fields (raw date/description) cross unchanged;
 * their invariants are the use case's (value objects') authority, never this mapper's.
 */
internal fun CreateExpenseRequest.toCommand(personId: String): CreateExpenseCommand = CreateExpenseCommand(
    date = date,
    personId = personId,
    description = description,
    amountInCents = amountInCents!!,
)
