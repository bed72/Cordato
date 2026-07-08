package com.bed.cordato.core.infrastructure.http.authentication.filters

import jakarta.inject.Inject

import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.assertFalse
import kotlin.test.assertEquals

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpRequest
import io.micronaut.http.client.HttpClient
import io.micronaut.http.client.annotation.Client
import io.micronaut.http.client.exceptions.HttpClientResponseException
import io.micronaut.test.extensions.junit5.annotation.MicronautTest

import com.bed.cordato.core.factories.LIVE_TOKEN
import com.bed.cordato.core.factories.SESSION_PERSON_ID
import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse

private const val DEAD_TOKEN = "dead-token"

@MicronautTest
class AuthenticatedFilterTest {

    @Inject
    @field:Client("/")
    lateinit var client: HttpClient

    private fun request(path: String, authorization: String? = null): HttpRequest<Any> {
        val request = HttpRequest.GET<Any>(path)
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun retrieve(path: String, authorization: String? = null): String =
        client.toBlocking().retrieve(request(path, authorization))

    private fun reject(path: String, authorization: String? = null): HttpClientResponseException =
        try {
            client.toBlocking().exchange(request(path, authorization), String::class.java)
            error("Expected the request to be refused with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    @Test
    fun `an unannotated route flows through untouched, with or without a token`() {
        assertEquals("open", retrieve("/v1/probe/open"))
        assertEquals("open", retrieve("/v1/probe/open", "Bearer $DEAD_TOKEN"))
    }

    @Test
    fun `a live session reaches the handler as the typed actor`() {
        assertEquals(SESSION_PERSON_ID, retrieve("/v1/probe/whoami", "Bearer $LIVE_TOKEN"))
    }

    @Test
    fun `a protected route without a token is refused with a neutral scalar 401`() {
        val exception = reject("/v1/probe/whoami")

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("UNAUTHENTICATED", body.code)
        assertTrue(body.errors.isEmpty())
    }

    @Test
    fun `a token resolving to no live session is refused with the same 401`() {
        val exception = reject("/v1/probe/whoami", "Bearer $DEAD_TOKEN")

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        assertEquals("UNAUTHENTICATED", exception.response.getBody(ErrorResponse::class.java).get().code)
    }

    @Test
    fun `absent, malformed and unresolvable tokens collapse to one indistinguishable 401`() {
        val rejections = listOf(
            reject("/v1/probe/whoami"),                         // absent
            reject("/v1/probe/whoami", DEAD_TOKEN),             // malformed: no Bearer scheme
            reject("/v1/probe/whoami", "Bearer "),              // malformed: blank token
            reject("/v1/probe/whoami", "Bearer $DEAD_TOKEN"),   // well-formed but unresolvable
        )

        val statuses = rejections.map { it.status }.toSet()
        val bodies = rejections.map { it.response.getBody(String::class.java).get() }.toSet()

        assertEquals(setOf(HttpStatus.UNAUTHORIZED), statuses)
        assertEquals(1, bodies.size, "401 bodies differ between causes: $bodies")
        rejections.forEach {
            assertFalse(it.response.headers.contains("WWW-Authenticate"), "leaked a WWW-Authenticate challenge")
            assertFalse(it.response.getBody(String::class.java).get().contains(DEAD_TOKEN), "echoed the token")
        }
    }
}
