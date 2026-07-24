package com.bed.cordato.features.identity.infrastructure.http.mappers.errors

import io.micronaut.http.HttpResponse

import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.responses.unauthorized
import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse

import com.bed.cordato.features.identity.domain.errors.DeleteAccountError

/**
 * Maps each domain [DeleteAccountError] to an HTTP status and a neutral [ErrorsResponse], as an `internal`
 * extension so the controller reads fluently (`error.toResponse(messages)`). This is the one place the HTTP
 * status *policy* for the account-deletion route lives; the shaping tijolos come from core's shared builders.
 *
 * [DeleteAccountError.InvalidCredentials] **and** [DeleteAccountError.PersonNotFound] resolve to the
 * **same** neutral `401 UNAUTHENTICATED`, reusing the code and i18n key (`error.authentication.message`) the
 * edge guard and identity's other step-up rejections emit — so a wrong confirmation password and an
 * orphaned session are indistinguishable from each other and from an absent/expired/revoked token. The
 * `code` is the machine contract and is never localized.
 */
internal fun DeleteAccountError.toResponse(messages: MessagePort): HttpResponse<ErrorsResponse> = when (this) {
    DeleteAccountError.InvalidCredentials, DeleteAccountError.PersonNotFound ->
        unauthorized("UNAUTHENTICATED", messages("error.authentication.message"))
}
