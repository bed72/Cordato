package com.bed.cordato.features.identity.infrastructure.http

import io.mockk.every
import io.mockk.verify
import io.mockk.clearMocks

import jakarta.inject.Inject

import kotlin.test.Test
import kotlin.test.BeforeTest
import kotlin.test.assertTrue
import kotlin.test.assertFalse
import kotlin.test.assertEquals

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpRequest
import io.micronaut.http.client.HttpClient
import io.micronaut.http.client.annotation.Client
import io.micronaut.test.extensions.junit5.annotation.MicronautTest
import io.micronaut.http.client.exceptions.HttpClientResponseException

import com.bed.cordato.core.factories.LIVE_TOKEN
import com.bed.cordato.core.factories.SESSION_PERSON_ID
import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse

import com.bed.cordato.features.identity.factories.person
import com.bed.cordato.features.identity.application.repositories.PersonRepository

import com.bed.cordato.features.identity.infrastructure.http.responses.PersonResponse

private const val DEAD_TOKEN = "dead-token"

/**
 * End-to-end cover of the first real protected route: `GET /persons/me` exercised through the edge guard
 * (filter + binder), the real `MeUseCase`, and the neutral-`401` error contract. Only the [PersonRepository]
 * is a double, so the whole mint→consume path runs; the fake session repository (wired globally) resolves
 * only [LIVE_TOKEN] to [SESSION_PERSON_ID].
 */
@MicronautTest
class PersonControllerTest {

    @Inject
    lateinit var repository: PersonRepository

    @Inject
    @field:Client("/")
    lateinit var client: HttpClient

    @BeforeTest
    fun reset() = clearMocks(repository)

    private fun request(authorization: String? = null): HttpRequest<Any> {
        val request = HttpRequest.GET<Any>("/v1/persons/me")
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun reject(authorization: String? = null): HttpClientResponseException =
        try {
            client.toBlocking().exchange(request(authorization), String::class.java)
            error("Expected the request to be refused with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    @Test
    fun `a live session returns 200 with the person and no password material`() {
        every { repository.findById(SESSION_PERSON_ID) } returns person(id = SESSION_PERSON_ID, hash = "bcrypt:leaky")

        val response = client.toBlocking().exchange(
            request("Bearer $LIVE_TOKEN"),
            PersonResponse::class.java,
        )

        assertEquals(HttpStatus.OK, response.status)
        val body = response.body()!!
        assertEquals(SESSION_PERSON_ID, body.id)
        assertEquals("Alice", body.name)
        assertEquals("alice@example.com", body.email)

        val raw = client.toBlocking().retrieve(request("Bearer $LIVE_TOKEN"), String::class.java)
        assertFalse(raw.contains("hash"), "response leaked a hash field: $raw")
        assertFalse(raw.contains("bcrypt"), "response leaked the hash value: $raw")
    }

    @Test
    fun `no token is refused with a neutral 401 before the use case runs`() {
        val exception = reject()

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("UNAUTHENTICATED", body.code)
        assertTrue(body.errors.isEmpty())
        verify(exactly = 0) { repository.findById(any()) }
    }

    @Test
    fun `an unresolvable token is refused with a neutral 401 before the use case runs`() {
        val exception = reject("Bearer $DEAD_TOKEN")

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        assertEquals("UNAUTHENTICATED", exception.response.getBody(ErrorResponse::class.java).get().code)
        verify(exactly = 0) { repository.findById(any()) }
    }

    @Test
    fun `a live session for a non-active person collapses into the same neutral 401`() {
        every { repository.findById(SESSION_PERSON_ID) } returns null

        val exception = reject("Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("UNAUTHENTICATED", body.code)
        assertTrue(body.errors.isEmpty())
        verify(exactly = 1) { repository.findById(SESSION_PERSON_ID) }
    }

    @Test
    fun `the orphan-session 401 is byte-indistinguishable from an invalid-token 401`() {
        every { repository.findById(SESSION_PERSON_ID) } returns null

        val orphan = reject("Bearer $LIVE_TOKEN")
        val invalid = reject("Bearer $DEAD_TOKEN")

        assertEquals(invalid.status, orphan.status)
        assertEquals(
            invalid.response.getBody(String::class.java).get(),
            orphan.response.getBody(String::class.java).get(),
            "orphan-session and invalid-token 401 bodies differ",
        )
    }
}
