package com.bed.cordato.features.budget.infrastructure.http.mappers.errors

import io.micronaut.http.HttpResponse

import com.bed.cordato.features.budget.domain.errors.CreateBudgetError

import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.responses.unprocessable
import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse

/**
 * Maps each domain [CreateBudgetError] to an HTTP status and a neutral [ErrorsResponse], as an `internal`
 * extension so the controller reads fluently (`error.toResponse(messages)`). This is the one place the HTTP
 * status *policy* for the create-budget route lives; the shaping comes from core's shared `unprocessable`
 * builder.
 *
 * Every rejection is a well-formed request the domain refused, so all four share a scalar `422` — the
 * status never signals *which* rejection occurred, and none is emitted as a field-level item (that is the
 * edge `400` path only). The message is resolved by i18n key; the `code` stays an inline constant — the
 * machine contract, never localized.
 */
internal fun CreateBudgetError.toResponse(messages: MessagePort): HttpResponse<ErrorsResponse> = when (this) {
    CreateBudgetError.InvalidNote ->
        unprocessable("INVALID_NOTE", messages("createBudget.error.invalidNote"))
    CreateBudgetError.InvalidAmount ->
        unprocessable("INVALID_AMOUNT", messages("createBudget.error.invalidAmount"))
    CreateBudgetError.InvalidPeriod ->
        unprocessable("INVALID_PERIOD", messages("createBudget.error.invalidPeriod"))
    CreateBudgetError.OverlappingBudget ->
        unprocessable("OVERLAPPING_BUDGET", messages("createBudget.error.overlappingBudget"))
}
