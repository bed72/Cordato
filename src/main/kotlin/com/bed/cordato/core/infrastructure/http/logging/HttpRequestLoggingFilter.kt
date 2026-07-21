package com.bed.cordato.core.infrastructure.http.logging

import java.util.UUID

import org.slf4j.MDC

import io.micronaut.core.order.Ordered
import io.micronaut.core.annotation.Order

import io.micronaut.http.HttpRequest
import io.micronaut.http.MutableHttpResponse
import io.micronaut.http.annotation.ServerFilter
import io.micronaut.http.annotation.RequestFilter
import io.micronaut.http.annotation.ResponseFilter

import com.bed.cordato.core.application.driven.ports.LoggerPort
import com.bed.cordato.core.domain.value_objects.LoggableValueObject

const val CORRELATION_ID_HEADER = "X-Correlation-Id"
const val CORRELATION_ID_MDC_KEY = "correlation_id"

private const val START_NANOS_ATTRIBUTE = "http.logging.start_nanos"
private const val CORRELATION_ID_ATTRIBUTE = "http.logging.correlation_id"

/**
 * Cross-cutting request/response log — mirrors [com.bed.cordato.core.infrastructure.http.authentication.filters.AuthenticatedFilter]'s
 * shape (`@ServerFilter(ServerFilter.MATCH_ALL_PATTERN)`, discovered by annotation). [Ordered.HIGHEST_PRECEDENCE]
 * makes its request phase run first and its response phase run last, wrapping every other filter
 * (including [com.bed.cordato.core.infrastructure.http.authentication.filters.AuthenticatedFilter]) so
 * even a request rejected before reaching a controller is still logged.
 *
 * Mints a per-request correlation id, stashed in the SLF4J [MDC] under [CORRELATION_ID_MDC_KEY] — the
 * same key a future OTEL trace id will occupy, so no call site changes when tracing lands — and echoed
 * to the client via [CORRELATION_ID_HEADER]. Logs method/path/status/duration through [LoggerPort] after
 * the response is known, at a level derived from the status range so a `4xx`/`5xx` is never silently
 * downgraded to `info`.
 */
@ServerFilter(ServerFilter.MATCH_ALL_PATTERN)
@Order(Ordered.HIGHEST_PRECEDENCE)
class HttpRequestLoggingFilter(private val logger: LoggerPort) {

    @RequestFilter
    fun request(request: HttpRequest<*>) {
        val correlationId = UUID.randomUUID().toString()

        MDC.put(CORRELATION_ID_MDC_KEY, correlationId)
        request.setAttribute(CORRELATION_ID_ATTRIBUTE, correlationId)
        request.setAttribute(START_NANOS_ATTRIBUTE, System.nanoTime().toString())
    }

    @ResponseFilter
    fun response(request: HttpRequest<*>, response: MutableHttpResponse<*>?, failure: Throwable?) {
        val correlationId = request.getAttribute(CORRELATION_ID_ATTRIBUTE, String::class.java).orElse(null)
        response?.header(CORRELATION_ID_HEADER, correlationId)

        val startNanos = request.getAttribute(START_NANOS_ATTRIBUTE, String::class.java).orElse(null)?.toLong()
        val durationMs = if (startNanos != null) (System.nanoTime() - startNanos) / 1_000_000 else 0L

        val attributes = mapOf(
            "method" to LoggableValueObject.Text(request.method.name),
            "path" to LoggableValueObject.Text(request.path),
            "status" to LoggableValueObject.Number(response?.status?.code ?: 500),
            "duration_ms" to LoggableValueObject.Number(durationMs),
        )

        when (val status = response?.status?.code ?: 500) {
            in 500..599 -> logger.error("HttpRequestLoggingFilter", "Handled request", attributes, failure)
            in 400..499 -> logger.warn("HttpRequestLoggingFilter", "Handled request", attributes)
            else -> logger.info("HttpRequestLoggingFilter", "Handled request", attributes)
        }

        MDC.remove(CORRELATION_ID_MDC_KEY)
    }
}
