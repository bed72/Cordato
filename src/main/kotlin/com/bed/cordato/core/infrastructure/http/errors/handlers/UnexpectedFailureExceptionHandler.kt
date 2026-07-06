package com.bed.cordato.core.infrastructure.http.errors.handlers

import org.slf4j.LoggerFactory

import jakarta.inject.Singleton

import io.micronaut.http.HttpRequest
import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Produces
import io.micronaut.http.server.exceptions.ExceptionHandler

import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse
import com.bed.cordato.core.infrastructure.http.responses.internalError
import com.bed.cordato.core.application.ports.MessageResolverPort

/**
 * The catch-all `500`: any exception no more-specific handler (nor a controller) dealt with. Because
 * Micronaut resolves the most specific handler by exception type, this only ever sees genuinely
 * unexpected failures — validation, malformed body and domain rejection are all handled upstream.
 *
 * The body is fixed and neutral: a stable code and a generic message resolved by key through core's
 * [MessageResolverPort], with no [ErrorResponse.errors]. The exception itself — message,
 * stacktrace, any SQL/path/type detail — is written **only** to the server log, never serialized,
 * honouring the system's non-leak invariant (an error response must not become an oracle): only the
 * generic bundle text reaches the client. The operator gets the detail; the client gets nothing exploitable.
 */
@Produces
@Singleton
class UnexpectedFailureExceptionHandler(private val messages: MessageResolverPort) :
    ExceptionHandler<Throwable, HttpResponse<ErrorResponse>> {

    private val logger = LoggerFactory.getLogger(UnexpectedFailureExceptionHandler::class.java)

    override fun handle(request: HttpRequest<*>, exception: Throwable): HttpResponse<ErrorResponse> {
        logger.error("Unhandled failure while serving {} {}", request.method, request.path, exception)

        return internalError("INTERNAL_ERROR", messages.invoke("error.internal.message"))
    }
}
