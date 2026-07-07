package com.bed.cordato.features.identity.infrastructure.http.mappers.responses

import com.bed.cordato.features.identity.domain.entities.PersonEntity

import com.bed.cordato.features.identity.infrastructure.http.responses.PersonResponse

/**
 * Projects a created [PersonEntity] into its public [PersonResponse], as an `internal` extension
 * (`person.toResponse()`). It reads only id/name/email and unwraps the value objects to their
 * strings — the `hash` is never read, so no password material can reach the wire.
 */
internal fun PersonEntity.toResponse(): PersonResponse = PersonResponse(
    id = id,
    name = name.value,
    email = email.value,
)
