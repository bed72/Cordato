package com.bed.cordato.features.identity.infrastructure.http.mappers.errors

import io.micronaut.http.HttpResponse

import com.bed.cordato.features.identity.domain.errors.SignInError

import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.responses.unauthorized
import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse

/**
 * Maps the domain [SignInError] to an HTTP status and a neutral [ErrorsResponse], as an `internal`
 * extension so the controller reads fluently (`error.toResponse(messages)`). This is the one place
 * the HTTP status *policy* for login lives; the `401`-shaping tijolo comes from core's shared
 * [unauthorized] builder.
 *
 * [SignInError.InvalidCredentials] resolves to the neutral `401 UNAUTHENTICATED` — the **same** shape
 * a protected route without a live session will emit, so login-refused and route-without-session are
 * indistinguishable by construction. The message is resolved by **stable key** through [MessagePort],
 * stays generic, and never says which factor failed nor echoes the attempted e-mail; the `code` is the
 * machine contract and is never localized.
 */
internal fun SignInError.toResponse(messages: MessagePort): HttpResponse<ErrorsResponse> = when (this) {
    SignInError.InvalidCredentials ->
        unauthorized("UNAUTHENTICATED", messages("signin.error.invalidCredentials"))
}
