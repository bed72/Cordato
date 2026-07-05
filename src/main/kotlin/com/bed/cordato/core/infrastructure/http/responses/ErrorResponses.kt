package com.bed.cordato.core.infrastructure.http.responses

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpResponse

/**
 * Shared builders for the cross-cutting [ErrorResponse] body at a given HTTP status — the reusable
 * "how to shape a rejection" tijolo that every driving adapter (controller or `ExceptionHandler`) and
 * error mapper composes, so no one constructs the body inline. The *policy* — which failure maps to which
 * status/code/message — stays with each caller; these own only the shape.
 *
 * The set covers the statuses the API actually emits in this body today: an edge/malformed `400` (the only
 * one that may carry a per-field [ErrorResponse.errors] breakdown — every other case is scalar), a
 * domain-rejection `422`, and an unexpected `500`. New statuses (401/404/409…) slot in the same way when a
 * real caller needs them.
 */

/**
 * `400 Bad Request` — a malformed/invalid request. [errors] carries the per-field breakdown for edge Bean
 * Validation (one item per violated field); it defaults to empty for scalar `400`s (malformed body).
 */
fun badRequest(
    code: String,
    message: String,
    errors: List<FieldErrorResponse> = emptyList(),
): HttpResponse<ErrorResponse> =
    HttpResponse.badRequest(ErrorResponse(code, message, errors))

/**
 * `422 Unprocessable Entity` — a well-formed request the domain refused. Stays **scalar** (a
 * `code`/`message`, no per-field [ErrorResponse.errors]); per-field breakdowns are the edge `400` path only.
 */
fun unprocessable(code: String, message: String): HttpResponse<ErrorResponse> =
    HttpResponse.status<ErrorResponse>(HttpStatus.UNPROCESSABLE_ENTITY).body(ErrorResponse(code, message))

/**
 * `500 Internal Server Error` — an unexpected failure. Always scalar and neutral; the caller logs the real
 * detail and passes only a generic [message] here, never leaking internals into the body.
 */
fun internalError(code: String, message: String): HttpResponse<ErrorResponse> =
    HttpResponse.serverError(ErrorResponse(code, message))
