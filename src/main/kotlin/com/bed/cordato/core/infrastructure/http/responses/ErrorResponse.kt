package com.bed.cordato.core.infrastructure.http.responses

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpResponse

import io.micronaut.serde.annotation.Serdeable

import io.swagger.v3.oas.annotations.media.Schema

/**
 * The single, shared error body used for every HTTP failure across every bounded context — one shape
 * for all rejections so the body structure itself is never a tell. Being cross-cutting (no context
 * knows it exists), it lives in the shared kernel (`core`), not in a feature. Mutually exclusive with
 * [DataResponse]: a failure response never carries `data`, a success response never carries `errors`.
 *
 * [errors] carries one item per relevant cause: exactly **one** [ErrorItemResponse] for a scalar failure
 * (domain rejection, malformed body, internal error, authentication), or one item **per violated field**
 * for an edge Bean Validation failure.
 */
@Serdeable
@Schema(description = "Corpo de erro compartilhado por toda falha HTTP: sempre um array de um ou mais itens.")
data class ErrorsResponse(
    @field:Schema(description = "Um item por causa relevante da falha.")
    val errors: List<ErrorItemResponse>,
)

/**
 * A single item inside [ErrorsResponse.errors]. [status] is the HTTP status code as a string (redundant
 * with the response header by JSON:API convention); [code] is a stable machine-readable token; [message]
 * is human-readable and, for leak-sensitive cases (e.g. identity's e-mail conflict), deliberately generic
 * so the endpoint can't be used as an oracle. [source] is present only when the failure is attributable to
 * a specific request field (edge validation) — scalar failures never carry it.
 */
@Serdeable
@Schema(description = "Um item do array errors.")
data class ErrorItemResponse(
    @field:Schema(description = "Código de status HTTP, como string.", example = "422")
    val status: String,
    @field:Schema(description = "Token estável, legível por máquina, que identifica a falha.", example = "INVALID_REQUEST")
    val code: String,
    @field:Schema(
        description = "Mensagem legível e localizável. Genérica em casos sensíveis a vazamento.",
        example = "A requisição contém campos inválidos.",
    )
    val message: String,
    @field:Schema(description = "Presente apenas quando o erro é atribuível a um campo específico do request.")
    val source: ErrorSourceResponse? = null,
)

/** [field] is the request field that violated a constraint — the final node of the validation path, never
 * the internal method/argument shape. */
@Serdeable
@Schema(description = "A origem de um item de erro atribuível a um campo do request.")
data class ErrorSourceResponse(
    @field:Schema(description = "Campo da requisição que violou a restrição.", example = "email")
    val field: String,
)

/**
 * Shared builders for the cross-cutting [ErrorsResponse] body at a given HTTP status — the reusable
 * "how to shape a rejection" tijolo that every driving adapter (controller or `ExceptionHandler`) and
 * error mapper composes, so no one constructs the body inline. The *policy* — which failure maps to which
 * status/code/message — stays with each caller; these own only the shape.
 *
 * The set covers the statuses the API actually emits in this body today: an edge/malformed `400` (the only
 * one that may carry a per-field breakdown — every other case is scalar), an authentication `401`, a
 * domain-rejection `422`, a rate-limit refusal `429`, and an unexpected `500`. New statuses (404/409…) slot
 * in the same way when a real caller needs them.
 */

/**
 * `400 Bad Request` — a malformed/invalid request. [errors] carries one [ErrorSourceResponse] per violated
 * field when the same [code]/[message] applies to each (defaults to empty, producing a single scalar item
 * with no `source`). A failure where each field needs its **own** message —
 * [com.bed.cordato.core.infrastructure.http.errors.handlers.ConstraintViolationExceptionHandler] — builds
 * its `List<ErrorItemResponse>` directly instead of going through this builder.
 */
fun badRequest(
    code: String,
    message: String,
    errors: List<ErrorSourceResponse> = emptyList(),
): HttpResponse<ErrorsResponse> {
    val items = if (errors.isEmpty()) {
        listOf(ErrorItemResponse(status = "400", code = code, message = message))
    } else {
        errors.map { source -> ErrorItemResponse(status = "400", code = code, message = message, source = source) }
    }

    return HttpResponse.badRequest(ErrorsResponse(items))
}

/**
 * `401 Unauthorized` — an authentication failure. Stays **scalar** (a single item, no `source`) and
 * deliberately carries **no** `WWW-Authenticate` header. Every authentication rejection — invalid sign-in
 * credentials or a protected route reached without a live session — resolves to this one shape, so neither
 * body, code, nor status can tell the causes apart.
 */
fun unauthorized(code: String, message: String): HttpResponse<ErrorsResponse> =
    HttpResponse.status<ErrorsResponse>(HttpStatus.UNAUTHORIZED)
        .body(ErrorsResponse(listOf(ErrorItemResponse("401", code, message))))

/**
 * `422 Unprocessable Entity` — a well-formed request the domain refused. Stays **scalar** (a single item,
 * no `source`); per-field breakdowns are the edge `400` path only.
 */
fun unprocessable(code: String, message: String): HttpResponse<ErrorsResponse> =
    HttpResponse.status<ErrorsResponse>(HttpStatus.UNPROCESSABLE_ENTITY)
        .body(ErrorsResponse(listOf(ErrorItemResponse("422", code, message))))

/**
 * `500 Internal Server Error` — an unexpected failure. Always scalar and neutral; the caller logs the real
 * detail and passes only a generic [message] here, never leaking internals into the body.
 */
fun internalError(code: String, message: String): HttpResponse<ErrorsResponse> =
    HttpResponse.serverError(ErrorsResponse(listOf(ErrorItemResponse("500", code, message))))

private const val RETRY_AFTER_HEADER = "Retry-After"

/**
 * `429 Too Many Requests` — a request refused by the rate limiter. Stays **scalar** (a single item, no
 * `source`), the same shape every other cross-cutting failure uses. [retryAfterSeconds] — the current
 * window's remaining lifetime, never a hardcoded constant — is carried as a [RETRY_AFTER_HEADER] response
 * header rather than a body field, the same "metadata belongs in a header, not the envelope" precedent the
 * request-logging filter's correlation id header already set.
 */
fun tooManyRequests(code: String, message: String, retryAfterSeconds: Long): HttpResponse<ErrorsResponse> =
    HttpResponse.status<ErrorsResponse>(HttpStatus.TOO_MANY_REQUESTS)
        .header(RETRY_AFTER_HEADER, retryAfterSeconds.toString())
        .body(ErrorsResponse(listOf(ErrorItemResponse("429", code, message))))
