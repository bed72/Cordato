package com.bed.cordato.core.infrastructure.http.errors.handlers

import io.micronaut.http.HttpRequest
import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Produces
import io.micronaut.context.annotation.Replaces
import io.micronaut.http.server.exceptions.ExceptionHandler
import io.micronaut.validation.exceptions.ConstraintExceptionHandler

import jakarta.inject.Singleton
import jakarta.validation.ConstraintViolationException

import com.bed.cordato.core.infrastructure.http.responses.FieldErrorResponse
import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse
import com.bed.cordato.core.infrastructure.http.responses.badRequest

/**
 * Renders a failed request-body validation as a `400` in the shared [ErrorResponse] shape, replacing
 * Micronaut's default handler (which emits its own `_embedded.errors` body) so the whole API keeps a
 * single error format across the edge (`400`) and domain (`422`) paths. This is the legitimate use of an
 * exception handler: a `@Valid` violation is genuinely *thrown* by the framework — unlike the domain's
 * sealed result, which is branched over, never caught.
 *
 * Living in the shared kernel (`core`), it knows nothing of any context: it only speaks
 * `jakarta.validation`. Each violation becomes one [FieldErrorResponse] — [FieldErrorResponse.field] is the request
 * field (the final node of the validation path, so the internal `method.arg` prefix never leaks) and
 * [FieldErrorResponse.message] is the constraint's own curated text (no raw pattern). Violations are reported
 * one-per-field instead of concatenated, so a multi-field failure tells the client exactly what failed.
 */
@Produces
@Singleton
@Replaces(ConstraintExceptionHandler::class)
class ConstraintViolationExceptionHandler :
    ExceptionHandler<ConstraintViolationException, HttpResponse<ErrorResponse>> {

    override fun handle(
        request: HttpRequest<*>,
        exception: ConstraintViolationException,
    ): HttpResponse<ErrorResponse> {
        val errors = exception.constraintViolations.map { violation ->
            FieldErrorResponse(
                field = violation.propertyPath.lastOrNull()?.name.orEmpty(),
                message = violation.message,
            )
        }

        return badRequest("INVALID_REQUEST", "A requisição contém campos inválidos.", errors)
    }
}
