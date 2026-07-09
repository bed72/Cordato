package com.bed.cordato.features.identity.infrastructure.http.mappers.errors

import io.micronaut.http.HttpResponse

import com.bed.cordato.features.identity.domain.errors.UpdateEmailError

import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.responses.unauthorized
import com.bed.cordato.core.infrastructure.http.responses.unprocessable
import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse

/**
 * Maps each domain [UpdateEmailError] to an HTTP status and a neutral [ErrorResponse], as an `internal`
 * extension so the controller reads fluently (`error.toResponse(messages)`). This is the one place the HTTP
 * status *policy* for the update-e-mail route lives; the shaping tijolos come from core's shared builders.
 *
 * [UpdateEmailError.InvalidEmail] resolves to a scalar `422 INVALID_EMAIL` — a well-formed request the domain
 * refused. [UpdateEmailError.EmailAlreadyInUse] resolves to a **generic, scalar** `422 EMAIL_UPDATE_REJECTED`:
 * it shares the **same status** as the other domain rejection so the status line cannot signal which one
 * happened, is never a `FieldError(field="email")`, never echoes the attempted e-mail, and its message stays
 * deliberately generic — the same account-discovery non-leak posture as signup, never a `409`.
 * [UpdateEmailError.InvalidCredentials] **and** [UpdateEmailError.PersonNotFound] resolve to the **same**
 * neutral `401 UNAUTHENTICATED`, reusing the code and i18n key (`error.authentication.message`) the edge
 * guard, [com.bed.cordato.features.identity.domain.errors.SignInError] and [MeError] emit — so a wrong
 * confirmation password and an orphaned session are indistinguishable from each other and from an
 * absent/expired/revoked token. The `code` is the machine contract and is never localized.
 */
internal fun UpdateEmailError.toResponse(messages: MessagePort): HttpResponse<ErrorResponse> = when (this) {
    UpdateEmailError.InvalidEmail ->
        unprocessable("INVALID_EMAIL", messages("updateEmail.error.invalidEmail"))
    UpdateEmailError.EmailAlreadyInUse ->
        unprocessable("EMAIL_UPDATE_REJECTED", messages("updateEmail.error.emailAlreadyInUse"))
    UpdateEmailError.InvalidCredentials, UpdateEmailError.PersonNotFound ->
        unauthorized("UNAUTHENTICATED", messages("error.authentication.message"))
}
