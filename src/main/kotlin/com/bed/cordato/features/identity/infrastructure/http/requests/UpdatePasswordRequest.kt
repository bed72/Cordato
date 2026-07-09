package com.bed.cordato.features.identity.infrastructure.http.requests

import jakarta.validation.constraints.Size
import jakarta.validation.constraints.NotBlank
import io.micronaut.serde.annotation.Serdeable
import io.swagger.v3.oas.annotations.media.Schema

import com.bed.cordato.features.identity.domain.value_objects.PasswordValueObject

/**
 * Body of `PATCH /persons/me/password` as it arrives over HTTP, validated at the edge (Bean Validation) before
 * the use case runs.
 *
 * `currentPassword` is validated for **presence only** (`@NotBlank`): the edge applies **no** password policy
 * to the confirmation secret, which only checks the raw attempt against the stored hash — enforcing a
 * length/strength rule here would reject a legitimate password set before a policy change. An incorrect
 * confirmation is refused later as the neutral `401`, never a `400` per field.
 *
 * `newPassword` mirrors the domain policy by *referencing the value object's own constant*
 * ([PasswordValueObject.MIN_LENGTH]) on `@Size` — never a copied literal, so the edge check can't drift from
 * the domain; the value object stays the single authority. `@NotBlank` gives the early presence `400`. Each
 * constraint's `message` is a `{key}` into the shared message bundle, not inline text, so every response text
 * has one localizable origin.
 */
@Serdeable
@Schema(description = "Nova senha da pessoa autenticada, com a senha atual para confirmação.")
data class UpdatePasswordRequest(
    @field:Schema(
        example = "current-s3cret",
        description = "Senha atual em texto puro, para confirmação. Não é aparada — espaços contam.",
    )
    @field:NotBlank(message = "{updatePassword.request.currentPassword.notBlank}")
    val currentPassword: String,

    @field:Schema(
        example = "new-str0ng-secret",
        description = "Nova senha em texto puro. Deve ter ao menos o tamanho mínimo da política e diferir da atual.",
    )
    @field:NotBlank(message = "{updatePassword.request.newPassword.notBlank}")
    @field:Size(min = PasswordValueObject.MIN_LENGTH, message = "{updatePassword.request.newPassword.minSize}")
    val newPassword: String,
)
