package com.bed.cordato.features.identity.infrastructure.http.requests

import io.micronaut.serde.annotation.Serdeable

import io.swagger.v3.oas.annotations.media.Schema

import jakarta.validation.constraints.NotBlank

/**
 * Login body as it arrives over HTTP. Unlike [com.bed.cordato.features.identity.infrastructure.http.requests.SignUpRequest],
 * the edge validates **presence only** (`@NotBlank`) — never `@Size`/`@Pattern`. Applying password
 * policy or e-mail format here would reject a legitimate user whose password predates a policy change
 * with a `400` before authentication is even attempted, and would split the signal from the generic
 * `401`. The edge only guarantees there is something to hand the use case; the use case owns every
 * authentication decision.
 *
 * Each constraint's `message` is a `{key}` into the shared bundle, resolved by the validator's
 * interpolator against the same `MessageSource` `core` exposes — one origin for every response text.
 */
@Serdeable
@Schema(description = "Credenciais de login: e-mail e senha.")
data class SignInRequest(
    @field:Schema(example = "gabriel@email.com", description = "E-mail da pessoa.")
    @field:NotBlank(message = "{signin.request.email.notBlank}")
    val email: String,

    @field:Schema(example = "super-s3cret", description = "Senha em texto puro.")
    @field:NotBlank(message = "{signin.request.password.notBlank}")
    val password: String,
)
