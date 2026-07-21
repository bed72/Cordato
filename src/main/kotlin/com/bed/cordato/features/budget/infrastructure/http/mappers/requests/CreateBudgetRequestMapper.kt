package com.bed.cordato.features.budget.infrastructure.http.mappers.requests

import com.bed.cordato.features.budget.application.driving.commands.CreateBudgetCommand
import com.bed.cordato.features.budget.infrastructure.http.requests.CreateBudgetRequest

/**
 * Builds the application's [CreateBudgetCommand] from the [CreateBudgetRequest] body and the authenticated
 * actor's `personId`, as an `internal` extension so the call site reads `request.toCommand(actor.personId)`.
 * The owner comes from the actor the edge guard resolved, never from the body — a person can only create
 * their own budget. `amountInCents`/`startDate`/`endDate` are non-null here: edge `@NotNull` validation
 * already ran and threw a `400` before this mapper, so `!!` cannot fail. `note` crosses unchanged; its
 * invariant is the use case's (value object's) authority, never this mapper's.
 */
internal fun CreateBudgetRequest.toCommand(personId: String): CreateBudgetCommand = CreateBudgetCommand(
    note = note,
    endDate = endDate!!,
    personId = personId,
    startDate = startDate!!,
    amountInCents = amountInCents!!,
)
