package com.bed.cordato.core.infrastructure.http.responses

import io.micronaut.serde.annotation.Serdeable

/**
 * A single field-level validation failure inside [ErrorResponse.errors]: [field] is the request field
 * that violated a constraint (the final node of the validation path, never the internal method/argument
 * shape), and [message] is the constraint's own curated text — no raw pattern or internal detail.
 */
@Serdeable
data class FieldErrorResponse(
    val field: String,
    val message: String,
)
