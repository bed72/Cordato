package com.bed.cordato.features.identity.infrastructure.http.responses

import io.micronaut.serde.annotation.Serdeable

/**
 * The public view of a created person, returned on a successful signup. Carries only the
 * identifier, name and e-mail — there is deliberately no field for the password or its hash,
 * so leaking password material is impossible by construction, not by discipline.
 */
@Serdeable
data class PersonResponse(
    val id: String,
    val name: String,
    val email: String,
)
