package com.bed.cordato.features.identity.infrastructure.http.mappers.errors

import io.micronaut.http.HttpResponse

import com.bed.cordato.features.identity.domain.errors.MeError

import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.responses.unauthorized
import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse

/**
 * Maps the domain [MeError] to an HTTP status and a neutral [ErrorResponse], as an `internal` extension so
 * the controller reads fluently (`error.toResponse(messages)`). This is the one place the HTTP status
 * *policy* for the `Me` route lives; the `401`-shaping tijolo comes from core's shared [unauthorized]
 * builder.
 *
 * [MeError.PersonNotFound] resolves to the neutral `401 UNAUTHENTICATED` — reusing the **same** code and
 * i18n key (`error.authentication.message`) the edge guard emits when a request carries no live session, so
 * an orphaned session is indistinguishable from an absent/expired/revoked token. The response never reveals
 * that the session pointed at a non-active person, and never echoes any identifier; the `code` is the
 * machine contract and is never localized.
 */
internal fun MeError.toResponse(messages: MessagePort): HttpResponse<ErrorResponse> = when (this) {
    MeError.PersonNotFound ->
        unauthorized("UNAUTHENTICATED", messages("error.authentication.message"))
}
