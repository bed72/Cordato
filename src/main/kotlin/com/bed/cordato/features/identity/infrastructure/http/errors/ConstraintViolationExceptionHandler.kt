package com.bed.cordato.features.identity.infrastructure.http.errors

import io.micronaut.http.HttpRequest
import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Produces
import io.micronaut.context.annotation.Replaces
import io.micronaut.http.server.exceptions.ExceptionHandler
import io.micronaut.validation.exceptions.ConstraintExceptionHandler

import jakarta.inject.Singleton
import jakarta.validation.ConstraintViolationException

/**
 * Renders a failed request-body validation as a `400` in the shared [ErrorResponse] shape, replacing
 * Micronaut's default handler (which emits its own `_embedded.errors` body) so the API keeps a single
 * error format across the edge (`400`) and domain (`422`) paths. This is the legitimate use of an
 * exception handler: a `@Valid` violation is genuinely *thrown* by the framework — unlike the domain's
 * sealed `SignUpResult`, which is branched over, never caught.
 *
 * The surfaced [message] is the constraint's own curated text (set on each annotation in the request),
 * so no raw regex or internal detail leaks; violations are joined for the rare multi-field case.
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
        val message = exception.constraintViolations
            .map { it.message }
            .distinct()
            .joinToString(" ")
            .ifBlank { "Requisição inválida." }

        return HttpResponse.badRequest(ErrorResponse("INVALID_REQUEST", message))
    }
}
