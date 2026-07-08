package com.bed.cordato.features.identity.infrastructure.http.requests

import io.micronaut.serde.annotation.Serdeable

import io.swagger.v3.oas.annotations.media.Schema

import jakarta.validation.constraints.Size
import jakarta.validation.constraints.NotBlank

import com.bed.cordato.features.identity.domain.value_objects.NameValueObject

/**
 * Body of `PATCH /persons/me` as it arrives over HTTP, validated at the edge (Bean Validation) before the
 * use case runs. The single field mirrors the domain name rule by *referencing the value object's own
 * definition* ([NameValueObject.MAX_LENGTH]) — never a copied literal, so the edge check can't drift from the
 * domain. The value object stays the single authority: these annotations are an earlier,
 * deliberately-equal-or-stricter guard (they see the raw value, before the trim the value object applies),
 * not a second independent rule.
 *
 * Each constraint's `message` is a `{key}` into the shared message bundle, not inline text: the validator's
 * interpolator resolves the key against the same `MessageSource` `core` exposes and re-interpolates the
 * nested constraint placeholder (`{max}`) — one origin for every response text, localizable per
 * `Accept-Language`.
 */
@Serdeable
@Schema(description = "Novo nome da pessoa autenticada.")
data class UpdateNameRequest(
    @field:Schema(
        example = "Gabriel",
        description = "Novo nome da pessoa. É aparado (trim) e não pode exceder o comprimento máximo.",
    )
    @field:NotBlank(message = "{updateName.request.name.notBlank}")
    @field:Size(max = NameValueObject.MAX_LENGTH, message = "{updateName.request.name.maxSize}")
    val name: String,
)
