package com.bed.cordato.features.identity.infrastructure.http.requests

import io.micronaut.serde.annotation.Serdeable

import jakarta.validation.constraints.Size
import jakarta.validation.constraints.Pattern
import jakarta.validation.constraints.NotBlank

import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject
import com.bed.cordato.features.identity.domain.value_objects.PasswordValueObject

/**
 * Signup body as it arrives over HTTP, validated at the edge (Bean Validation) before the use case
 * runs. Every constraint that mirrors a domain rule *references the value object's own definition* —
 * its `const` bound or [EmailValueObject.PATTERN] — never a copied literal, so the edge check can't
 * drift from the domain. The value object stays the single authority: these annotations are an
 * earlier, deliberately-equal-or-stricter guard (they see the raw value, before the trim/lowercase
 * the value objects apply), not a second independent rule.
 *
 * `password` has no `@NotBlank`: the domain does not trim passwords, so an all-whitespace password of
 * sufficient length is valid — only its minimum length is enforced.
 */
@Serdeable
data class SignUpRequest(
    @field:NotBlank(message = "O nome é obrigatório.")
    @field:Size(max = NameValueObject.MAX_LENGTH, message = "O nome deve ter no máximo {max} caracteres.")
    val name: String,

    @field:NotBlank(message = "O e-mail é obrigatório.")
    @field:Pattern(regexp = EmailValueObject.PATTERN, message = "O e-mail informado é inválido.")
    val email: String,

    @field:Size(min = PasswordValueObject.MIN_LENGTH, message = "A senha deve ter ao menos {min} caracteres.")
    val password: String,
)
