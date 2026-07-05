package com.bed.cordato.features.identity.infrastructure.http.mappers

import io.micronaut.http.HttpResponse

import com.bed.cordato.features.identity.domain.errors.SignUpError
import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse
import com.bed.cordato.core.infrastructure.http.responses.unprocessable

/**
 * Maps each domain [SignUpError] to an HTTP status and a neutral [ErrorResponse] (the shared error body
 * from `core`), as an `internal` extension so the controller reads fluently (`error.toResponse()`).
 * This is the one place the HTTP status *policy* for identity lives; the `422`-shaping tijolo itself comes
 * from core's shared [unprocessable] builder.
 *
 * Every rejection is a `422 Unprocessable Entity`: sharing a single status keeps the code itself
 * from signalling *which* rejection happened. Each error stays **scalar** — a `code`/`message` with no
 * per-field [ErrorResponse.errors]. [WeakPassword] MAY state the public minimum length (it reveals
 * nothing about any person), while [EmailAlreadyInUse] gets a generic code and message that never confirm
 * the e-mail is registered — and, crucially, is never turned into a `FieldError(field = "email", ...)`,
 * which would reintroduce the account-discovery oracle (identity's non-leak invariant).
 */
internal fun SignUpError.toResponse(): HttpResponse<ErrorResponse> = when (this) {
    SignUpError.InvalidName -> unprocessable("INVALID_NAME", "O nome informado é inválido.")
    SignUpError.InvalidEmail -> unprocessable("INVALID_EMAIL", "O e-mail informado é inválido.")
    SignUpError.EmailAlreadyInUse -> unprocessable("SIGNUP_REJECTED", "Não foi possível concluir o cadastro.")
    is SignUpError.WeakPassword -> unprocessable("WEAK_PASSWORD", "A senha deve ter ao menos $minLength caracteres.")
}
