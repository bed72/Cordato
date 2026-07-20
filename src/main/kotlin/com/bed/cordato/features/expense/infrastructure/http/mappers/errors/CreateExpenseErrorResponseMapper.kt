package com.bed.cordato.features.expense.infrastructure.http.mappers.errors

import io.micronaut.http.HttpResponse

import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.responses.unprocessable
import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse

import com.bed.cordato.features.expense.domain.errors.CreateExpenseError

/**
 * Maps each domain [CreateExpenseError] to an HTTP status and a neutral [ErrorsResponse], as an `internal`
 * extension so the controller reads fluently (`error.toResponse(messages)`). This is the one place the HTTP
 * status *policy* for the register-expense route lives; the shaping comes from core's shared `unprocessable`
 * builder.
 *
 * Every rejection is a well-formed request the domain refused, so all three share a scalar `422` — the status
 * never signals *which* rejection occurred, and none is emitted as a field-level item (that is the edge `400`
 * path only). The message is resolved by i18n key; the `code` stays an inline constant — the machine
 * contract, never localized.
 */
internal fun CreateExpenseError.toResponse(messages: MessagePort): HttpResponse<ErrorsResponse> = when (this) {
    CreateExpenseError.InvalidAmount ->
        unprocessable("INVALID_AMOUNT", messages("createExpense.error.invalidAmount"))
    CreateExpenseError.FutureDate ->
        unprocessable("FUTURE_DATE", messages("createExpense.error.futureDate"))
    CreateExpenseError.InvalidDescription ->
        unprocessable("INVALID_DESCRIPTION", messages("createExpense.error.invalidDescription"))
}
