package com.bed.cordato.features.budget.infrastructure.http.mappers.errors

import io.micronaut.http.HttpResponse

import com.bed.cordato.features.budget.domain.errors.UpdateBudgetError

import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.responses.notFound
import com.bed.cordato.core.infrastructure.http.responses.unprocessable
import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse

/**
 * Maps each domain [UpdateBudgetError] to an HTTP status and a neutral [ErrorsResponse], as an `internal`
 * extension so the controller reads fluently (`error.toResponse(messages)`). This is the one place the HTTP
 * status *policy* for the edit-budget route lives.
 *
 * The four validation reasons are a well-formed request the domain refused, so they share a scalar `422`
 * via core's `unprocessable` builder — same shape/policy as [CreateBudgetError]'s mapper. [BudgetNotFound]
 * is the first `404` of the API, via core's `notFound` builder: an unknown id, one belonging to another
 * person, and an already-removed one are all indistinguishable from this response. The message is resolved
 * by i18n key; the `code` stays an inline constant — the machine contract, never localized.
 */
internal fun UpdateBudgetError.toResponse(messages: MessagePort): HttpResponse<ErrorsResponse> = when (this) {
    UpdateBudgetError.InvalidNote ->
        unprocessable("INVALID_NOTE", messages("updateBudget.error.invalidNote"))
    UpdateBudgetError.InvalidAmount ->
        unprocessable("INVALID_AMOUNT", messages("updateBudget.error.invalidAmount"))
    UpdateBudgetError.InvalidPeriod ->
        unprocessable("INVALID_PERIOD", messages("updateBudget.error.invalidPeriod"))
    UpdateBudgetError.OverlappingBudget ->
        unprocessable("OVERLAPPING_BUDGET", messages("updateBudget.error.overlappingBudget"))
    UpdateBudgetError.BudgetNotFound ->
        notFound("BUDGET_NOT_FOUND", messages("updateBudget.error.budgetNotFound"))
}
