package com.bed.cordato.features.budget.infrastructure.http.mappers.requests

import com.bed.cordato.features.budget.application.driving.commands.UpdateBudgetCommand
import com.bed.cordato.features.budget.infrastructure.http.requests.UpdateBudgetRequest

/**
 * Builds the application's [UpdateBudgetCommand] from the [UpdateBudgetRequest] body, the `id` resolved from
 * the URL path, and the authenticated actor's `personId`, as an `internal` extension so the call site reads
 * `request.toCommand(budgetId, personId)`. The owner comes from the actor the edge guard resolved, never
 * from the body — a person can only edit their own budget. `amountInCents`/`startDate`/`endDate` are
 * non-null here: edge `@NotNull` validation already ran and threw a `400` before this mapper, so `!!` cannot
 * fail. `note` crosses unchanged; its invariant is the use case's (value object's) authority, never this
 * mapper's.
 */
internal fun UpdateBudgetRequest.toCommand(budgetId: String, personId: String): UpdateBudgetCommand = UpdateBudgetCommand(
    note = note,
    budgetId = budgetId,
    personId = personId,
    endDate = endDate!!,
    startDate = startDate!!,
    amountInCents = amountInCents!!,
)
