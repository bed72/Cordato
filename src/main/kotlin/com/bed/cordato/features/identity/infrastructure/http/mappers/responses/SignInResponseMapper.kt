package com.bed.cordato.features.identity.infrastructure.http.mappers.responses

import com.bed.cordato.features.identity.application.results.SignInResult

import com.bed.cordato.features.identity.infrastructure.http.responses.SignInResponse

/**
 * Projects a successful login into its [SignInResponse], as an `internal` extension
 * (`result.toResponse()`). It reads the plaintext token straight off the result and the expiry off
 * the opened session — the session's `hashToken` is never read, so no token hash reaches the wire.
 */
internal fun SignInResult.Success.toResponse(): SignInResponse = SignInResponse(
    token = token,
    expiresAt = session.expiresAt,
)
