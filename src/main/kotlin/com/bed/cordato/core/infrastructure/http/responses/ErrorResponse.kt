package com.bed.cordato.core.infrastructure.http.responses

import io.micronaut.serde.annotation.Serdeable

/**
 * The single, shared error body used for every HTTP failure across every bounded context — one shape
 * for all rejections so the body structure itself is never a tell. Being cross-cutting (no context
 * knows it exists), it lives in the shared kernel (`core`), not in a feature.
 *
 * [code] is a stable machine-readable token; [message] is human-readable and, for leak-sensitive cases
 * (e.g. identity's e-mail conflict), deliberately generic so the endpoint can't be used as an oracle.
 * [errors] carries a per-field breakdown for edge Bean Validation failures — one item per violated
 * field — and stays empty for scalar failures (domain rejection, malformed body, internal error), which
 * keep everything in [message]. It is additive: an empty list degrades to the plain `code`/`message` body.
 */
@Serdeable
data class ErrorResponse(
    val code: String,
    val message: String,
    val errors: List<FieldErrorResponse> = emptyList(),
)
