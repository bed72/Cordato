package com.bed.cordato.features.identity.infrastructure.http.mappers.errors

import io.micronaut.http.HttpResponse

import com.bed.cordato.features.identity.domain.errors.UpdateNameError

import com.bed.cordato.core.application.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.responses.unauthorized
import com.bed.cordato.core.infrastructure.http.responses.unprocessable
import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse

/**
 * Maps each domain [UpdateNameError] to an HTTP status and a neutral [ErrorResponse], as an `internal`
 * extension so the controller reads fluently (`error.toResponse(messages)`). This is the one place the HTTP
 * status *policy* for the update-name route lives; the shaping tijolos come from core's shared builders.
 *
 * [UpdateNameError.InvalidName] resolves to a scalar `422 INVALID_NAME` — a well-formed request the domain
 * refused. [UpdateNameError.PersonNotFound] resolves to the neutral `401 UNAUTHENTICATED`, reusing the
 * **same** code and i18n key (`error.authentication.message`) the edge guard and [MeError] emit, so an
 * orphaned session is indistinguishable from an absent/expired/revoked token. The response never reveals
 * that the session pointed at a non-active person, and never echoes any identifier; the `code` is the machine
 * contract and is never localized.
 */
internal fun UpdateNameError.toResponse(messages: MessagePort): HttpResponse<ErrorResponse> = when (this) {
    UpdateNameError.InvalidName ->
        unprocessable("INVALID_NAME", messages("updateName.error.invalidName"))
    UpdateNameError.PersonNotFound ->
        unauthorized("UNAUTHENTICATED", messages("error.authentication.message"))
}
