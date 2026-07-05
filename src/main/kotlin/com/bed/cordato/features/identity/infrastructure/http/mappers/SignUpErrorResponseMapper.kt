package com.bed.cordato.features.identity.infrastructure.http.mappers

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpResponse

import com.bed.cordato.features.identity.domain.errors.SignUpError
import com.bed.cordato.features.identity.infrastructure.http.errors.ErrorResponse

/**
 * Maps each domain [SignUpError] to an HTTP status and a neutral [com.bed.cordato.features.identity.infrastructure.http.errors.ErrorResponse], as an
 * `internal` extension so the controller reads fluently (`error.toHttpResponse()`). This is the
 * one place the HTTP status policy lives.
 *
 * Every rejection is a `422 Unprocessable Entity`: sharing a single status keeps the code itself
 * from signalling *which* rejection happened. [WeakPassword] MAY state the public
 * minimum length (it reveals nothing about any person), while [EmailAlreadyInUse]
 * gets a generic code and message that never confirm the e-mail is registered — so the endpoint
 * can't serve as an account-discovery oracle (identity's non-leak invariant).
 */
internal fun SignUpError.toHttpResponse(): HttpResponse<ErrorResponse> = when (this) {
    SignUpError.InvalidName -> unprocessable("INVALID_NAME", "O nome informado é inválido.")
    SignUpError.InvalidEmail -> unprocessable("INVALID_EMAIL", "O e-mail informado é inválido.")
    SignUpError.EmailAlreadyInUse -> unprocessable("SIGNUP_REJECTED", "Não foi possível concluir o cadastro.")
    is SignUpError.WeakPassword -> unprocessable("WEAK_PASSWORD", "A senha deve ter ao menos $minLength caracteres.")
}

private fun unprocessable(code: String, message: String): HttpResponse<ErrorResponse> =
    HttpResponse.status<ErrorResponse>(HttpStatus.UNPROCESSABLE_ENTITY).body(ErrorResponse(code, message))
