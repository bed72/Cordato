package com.bed.cordato.features.identity.infrastructure.http.requests

import io.micronaut.serde.annotation.Serdeable

import io.swagger.v3.oas.annotations.media.Schema

import jakarta.validation.constraints.Pattern
import jakarta.validation.constraints.NotBlank

import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

/**
 * Body of `PATCH /persons/me/email` as it arrives over HTTP, validated at the edge (Bean Validation) before
 * the use case runs. The `email` constraint mirrors the domain rule by *referencing the value object's own
 * definition* ([EmailValueObject.PATTERN]) — never a copied literal, so the edge check can't drift from the
 * domain; the value object stays the single authority (these annotations see the raw value, before the
 * trim/lowercase it applies, so the edge is a deliberately-equal-or-stricter guard).
 *
 * `password` is validated for **presence only** (`@NotBlank`): the edge applies **no** password policy, since
 * confirmation only checks the raw attempt against the stored hash — enforcing a length/strength rule here
 * would reject a legitimate password set before a policy change. An incorrect password is refused later as
 * the neutral `401`, never a `400` per field.
 *
 * Each constraint's `message` is a `{key}` into the shared message bundle, not inline text: the validator's
 * interpolator resolves the key against the same `MessageSource` `core` exposes — one origin for every
 * response text, localizable per `Accept-Language`.
 */
@Serdeable
@Schema(description = "Novo e-mail da pessoa autenticada, com a senha atual para confirmação.")
data class UpdateEmailRequest(
    @field:Schema(
        example = "gabriel@email.com",
        description = "Novo e-mail da pessoa. Normalizado (trim + lowercase); deve ser um endereço válido.",
    )
    @field:NotBlank(message = "{updateEmail.request.email.notBlank}")
    @field:Pattern(regexp = EmailValueObject.PATTERN, message = "{updateEmail.request.email.pattern}")
    val email: String,

    @field:Schema(
        example = "super-s3cret",
        description = "Senha atual em texto puro, para confirmação. Não é aparada — espaços contam.",
    )
    @field:NotBlank(message = "{updateEmail.request.password.notBlank}")
    val password: String,
)
