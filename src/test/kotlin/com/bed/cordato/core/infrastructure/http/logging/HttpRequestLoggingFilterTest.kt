package com.bed.cordato.core.infrastructure.http.logging

import jakarta.inject.Inject

import kotlin.test.Test
import kotlin.test.BeforeTest
import kotlin.test.assertTrue
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNotNull

import io.micronaut.http.HttpRequest
import io.micronaut.http.client.HttpClient
import io.micronaut.http.client.annotation.Client
import io.micronaut.test.extensions.junit5.annotation.MicronautTest
import io.micronaut.http.client.exceptions.HttpClientResponseException

import com.bed.cordato.core.factories.FakeLoggerPort
import com.bed.cordato.core.application.driven.ports.LoggerPort
import com.bed.cordato.core.domain.value_objects.LoggableValueObject

@MicronautTest
internal class HttpRequestLoggingFilterTest {

    @Inject
    @field:Client("/")
    lateinit var client: HttpClient

    @Inject
    lateinit var port: LoggerPort

    private val logger get() = port as FakeLoggerPort

    @BeforeTest
    fun setUp() {
        logger.events.clear()
    }

    private fun exchangeOpen(): io.micronaut.http.HttpResponse<String> =
        client.toBlocking().exchange(HttpRequest.GET<Any>("/v1/probe/open"), String::class.java)

    private fun rejectWhoami(): HttpClientResponseException =
        try {
            client.toBlocking().exchange(HttpRequest.GET<Any>("/v1/probe/whoami"), String::class.java)
            error("Expected the request to be refused with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    private fun requestEvents(): List<FakeLoggerPort.Event> = logger.events.filter { it.component == "HttpRequestLoggingFilter" }

    @Test
    fun `a successful request is logged at info with method, path, status and duration`() {
        val response = exchangeOpen()

        val event = requestEvents().single()
        assertEquals("INFO", event.level)
        assertEquals("GET", (event.attributes["method"] as LoggableValueObject.Text).value)
        assertTrue((event.attributes["duration_ms"] as LoggableValueObject.Number).value.toLong() >= 0)
        assertEquals("/v1/probe/open", (event.attributes["path"] as LoggableValueObject.Text).value)
        assertEquals(response.status.code, (event.attributes["status"] as LoggableValueObject.Number).value)
    }

    @Test
    fun `a rejected request is still logged, at a non-info level, with the effective status`() {
        val exception = rejectWhoami()

        val event = requestEvents().single()
        assertEquals("WARN", event.level)
        assertEquals(exception.status.code, (event.attributes["status"] as LoggableValueObject.Number).value)
    }

    @Test
    fun `every response carries a correlation id header`() {
        val response = exchangeOpen()

        assertNotNull(response.header(CORRELATION_ID_HEADER))
    }

    @Test
    fun `distinct requests receive distinct correlation ids`() {
        val first = exchangeOpen().header(CORRELATION_ID_HEADER)
        val second = exchangeOpen().header(CORRELATION_ID_HEADER)

        assertNotEquals(first, second)
    }
}
