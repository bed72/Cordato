package com.bed.cordato.features.identity.infrastructure.http.mappers

import io.micronaut.http.HttpResponse
import io.micronaut.context.LocalizedMessageSource

import com.bed.cordato.features.identity.domain.errors.SignUpError
import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse
import com.bed.cordato.core.infrastructure.http.responses.unprocessable
import com.bed.cordato.core.infrastructure.i18n.resolve

/**
 * Maps each domain [SignUpError] to an HTTP status and a neutral [ErrorResponse] (the shared error body
 * from `core`), as an `internal` extension so the controller reads fluently (`error.toResponse(messages)`).
 * This is the one place the HTTP status *policy* for identity lives; the `422`-shaping tijolo itself comes
 * from core's shared [unprocessable] builder.
 *
 * The human-readable text is resolved by **stable key** from the request-scoped [LocalizedMessageSource]
 * (passed in by the controller), never inlined here — the code stays the machine-readable contract, the
 * bundle owns the words. Every rejection is a `422 Unprocessable Entity`: sharing a single status keeps
 * the code itself from signalling *which* rejection happened. Each error stays **scalar** — a
 * `code`/`message` with no per-field [ErrorResponse.errors]. [SignUpError.WeakPassword] MAY state the
 * public minimum length (it reveals nothing about any person) by interpolating `minLength` into its
 * message, while [SignUpError.EmailAlreadyInUse] gets a generic code and message that never confirm the
 * e-mail is registered — and, crucially, is never turned into a `FieldError(field = "email", ...)`, which
 * would reintroduce the account-discovery oracle (identity's non-leak invariant).
 */
internal fun SignUpError.toResponse(messages: LocalizedMessageSource): HttpResponse<ErrorResponse> = when (this) {
    SignUpError.InvalidName ->
        unprocessable("INVALID_NAME", messages.resolve("signup.error.invalidName"))
    SignUpError.InvalidEmail ->
        unprocessable("INVALID_EMAIL", messages.resolve("signup.error.invalidEmail"))
    SignUpError.EmailAlreadyInUse ->
        unprocessable("SIGNUP_REJECTED", messages.resolve("signup.error.emailAlreadyInUse"))
    is SignUpError.WeakPassword ->
        unprocessable("WEAK_PASSWORD", messages.resolve("signup.error.weakPassword", mapOf("minLength" to minLength)))
}
