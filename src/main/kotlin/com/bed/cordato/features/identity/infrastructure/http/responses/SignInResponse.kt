package com.bed.cordato.features.identity.infrastructure.http.responses

import java.time.Instant

import io.micronaut.serde.annotation.Serdeable

import io.swagger.v3.oas.annotations.media.Schema

/**
 * The body of a successful login: the opaque [token] in the clear (the client's only chance to keep
 * it) and the session's [expiresAt]. Deliberately carries neither the typed password, its hash, nor
 * the token's hash — none of that can reach the wire.
 */
@Serdeable
@Schema(description = "Sessão criada no login. Contém o token opaco e sua expiração.")
data class SignInResponse(
    @field:Schema(
        description = "Token opaco da sessão, em claro. Devolvido uma única vez.",
        example = "3q2-7f1a9c4e8b6d0f2a1c3e5g7i9k1m3o5q7s9u1w3y5a7c9e",
    )
    val token: String,
    @field:Schema(description = "Instante em que a sessão expira.", example = "2026-07-07T12:00:00Z")
    val expiresAt: Instant,
)
