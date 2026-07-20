package com.bed.cordato.features.identity.infrastructure.http.mappers.errors

import io.micronaut.http.HttpResponse

import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.responses.unauthorized
import com.bed.cordato.core.infrastructure.http.responses.unprocessable
import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse

import com.bed.cordato.features.identity.domain.errors.UpdatePasswordError
import com.bed.cordato.features.identity.domain.value_objects.PasswordValueObject

/**
 * Maps each domain [UpdatePasswordError] to an HTTP status and a neutral [ErrorsResponse], as an `internal`
 * extension so the controller reads fluently (`error.toResponse(messages)`). This is the one place the HTTP
 * status *policy* for the update-password route lives; the shaping tijolos come from core's shared builders.
 *
 * [UpdatePasswordError.WeakPassword] resolves to a scalar `422 WEAK_PASSWORD` (its message may state the
 * **public** minimum length, interpolated from [PasswordValueObject.MIN_LENGTH] — the value object's own
 * constant, never a copied literal) and [UpdatePasswordError.SamePassword] to a scalar `422 SAME_PASSWORD`:
 * both are **public** rules (neither reveals the existence of anyone's account), so each may carry a specific
 * code/message, and they share the **same status** so the status line cannot signal which one happened.
 * [UpdatePasswordError.InvalidCredentials] **and** [UpdatePasswordError.PersonNotFound] resolve to the
 * **same** neutral `401 UNAUTHENTICATED`, reusing the code and i18n key (`error.authentication.message`) the
 * edge guard and identity's other rejections emit — so a wrong confirmation password and an orphaned session
 * are indistinguishable from each other and from an absent/expired/revoked token. The `code` is the machine
 * contract and is never localized.
 */
internal fun UpdatePasswordError.toResponse(messages: MessagePort): HttpResponse<ErrorsResponse> = when (this) {
    UpdatePasswordError.WeakPassword ->
        unprocessable(
            "WEAK_PASSWORD",
            messages("updatePassword.error.weakPassword", mapOf("minLength" to PasswordValueObject.MIN_LENGTH)),
        )
    UpdatePasswordError.SamePassword ->
        unprocessable("SAME_PASSWORD", messages("updatePassword.error.samePassword"))
    UpdatePasswordError.InvalidCredentials, UpdatePasswordError.PersonNotFound ->
        unauthorized("UNAUTHENTICATED", messages("error.authentication.message"))
}
