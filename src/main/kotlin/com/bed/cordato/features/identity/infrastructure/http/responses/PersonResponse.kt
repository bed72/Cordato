package com.bed.cordato.features.identity.infrastructure.http.responses

import io.micronaut.serde.annotation.Serdeable

import io.swagger.v3.oas.annotations.media.Schema

/**
 * The public view of a created person, returned on a successful signup. Carries only the
 * identifier, name and e-mail — there is deliberately no field for the password or its hash,
 * so leaking password material is impossible by construction, not by discipline.
 */
@Serdeable
@Schema(description = "Visão pública de uma pessoa cadastrada. Nunca inclui senha ou hash.")
data class PersonResponse(
    @field:Schema(description = "Identificador único da pessoa.", example = "018f9e2a-7b3c-7c4d-9e2a-1b2c3d4e5f60")
    val id: String,
    @field:Schema(description = "Nome da pessoa.", example = "Alice")
    val name: String,
    @field:Schema(description = "E-mail normalizado da pessoa.", example = "alice@example.com")
    val email: String,
)
