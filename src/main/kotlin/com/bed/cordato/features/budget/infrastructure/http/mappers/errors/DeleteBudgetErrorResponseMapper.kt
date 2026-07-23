package com.bed.cordato.features.budget.infrastructure.http.mappers.errors

import io.micronaut.http.HttpResponse

import com.bed.cordato.features.budget.domain.errors.DeleteBudgetError

import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.responses.notFound
import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse

/**
 * Maps the single domain [DeleteBudgetError] to an HTTP status and a neutral [ErrorsResponse], as an
 * `internal` extension so the controller reads fluently (`error.toResponse(messages)`).
 *
 * [DeleteBudgetError.BudgetNotFound] is a scalar `404` via core's `notFound` builder — an unknown id, one
 * belonging to another person, and an already-removed one are all indistinguishable from this response, the
 * same policy [UpdateBudgetError]'s mapper applies. The message is resolved by i18n key; the `code` stays
 * an inline constant — the machine contract, never localized.
 */
internal fun DeleteBudgetError.toResponse(messages: MessagePort): HttpResponse<ErrorsResponse> = when (this) {
    DeleteBudgetError.BudgetNotFound ->
        notFound("BUDGET_NOT_FOUND", messages("deleteBudget.error.budgetNotFound"))
}
