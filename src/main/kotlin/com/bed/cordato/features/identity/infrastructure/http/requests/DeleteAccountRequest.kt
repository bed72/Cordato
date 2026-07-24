package com.bed.cordato.features.identity.infrastructure.http.requests

import jakarta.validation.constraints.NotBlank
import io.micronaut.serde.annotation.Serdeable
import io.swagger.v3.oas.annotations.media.Schema

/**
 * Body of `DELETE /persons/me` as it arrives over HTTP, validated at the edge (Bean Validation) before the
 * use case runs.
 *
 * `password` is validated for **presence only** (`@NotBlank`): the edge applies **no** password policy to
 * the confirmation secret, which only checks the raw attempt against the stored hash — the same posture
 * [UpdatePasswordRequest]'s `currentPassword` and [UpdateEmailRequest]'s `password` already take. An
 * incorrect confirmation is refused later as the neutral `401`, never a `400` per field.
 */
@Serdeable
@Schema(description = "Senha atual da pessoa autenticada, para confirmação da exclusão da conta.")
data class DeleteAccountRequest(
    @field:Schema(
        example = "current-s3cret",
        description = "Senha atual em texto puro, para confirmação. Não é aparada — espaços contam.",
    )
    @field:NotBlank(message = "{deleteAccount.request.password.notBlank}")
    val password: String,
)
