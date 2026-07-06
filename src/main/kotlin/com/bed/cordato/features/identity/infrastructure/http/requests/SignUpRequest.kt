package com.bed.cordato.features.identity.infrastructure.http.requests

import io.micronaut.serde.annotation.Serdeable

import io.swagger.v3.oas.annotations.media.Schema

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
 *
 * Each constraint's `message` is a `{key}` into the shared message bundle, not inline text: the
 * validator's interpolator resolves the key against the same `MessageSource` `core` exposes and
 * re-interpolates the nested constraint placeholders (`{max}`, `{min}`) — one origin for every response
 * text, localizable per `Accept-Language`. The `regexp`/`max`/`min` bounds still reference the value
 * objects' own definitions ([NameValueObject.MAX_LENGTH], [EmailValueObject.PATTERN],
 * [PasswordValueObject.MIN_LENGTH]) so the edge can't drift from the domain rule; only the text moved.
 */
@Serdeable
@Schema(description = "Dados de cadastro de uma nova pessoa.")
data class SignUpRequest(
    @field:Schema(
        example = "Gabriel",
        description = "Nome da pessoa. É aparado (trim) e não pode exceder o comprimento máximo.",
    )
    @field:NotBlank(message = "{signup.request.name.notBlank}")
    @field:Size(max = NameValueObject.MAX_LENGTH, message = "{signup.request.name.maxSize}")
    val name: String,

    @field:Schema(
        example = "gabriel@email.com",
        description = "E-mail da pessoa. Normalizado (trim + lowercase); deve ser um endereço válido.",
    )
    @field:NotBlank(message = "{signup.request.email.notBlank}")
    @field:Pattern(regexp = EmailValueObject.PATTERN, message = "{signup.request.email.pattern}")
    val email: String,

    @field:Schema(
        example = "super-s3cret",
        description = "Senha em texto puro; mínimo de 8 caracteres. Não é aparada — espaços contam.",
    )
    @field:Size(min = PasswordValueObject.MIN_LENGTH, message = "{signup.request.password.minSize}")
    val password: String,
)
