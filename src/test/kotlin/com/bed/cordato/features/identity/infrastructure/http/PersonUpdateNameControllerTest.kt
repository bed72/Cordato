package com.bed.cordato.features.identity.infrastructure.http

import io.mockk.slot
import io.mockk.every
import io.mockk.verify
import io.mockk.clearMocks

import jakarta.inject.Inject

import kotlin.test.Test
import kotlin.test.BeforeTest
import kotlin.test.assertTrue
import kotlin.test.assertFalse
import kotlin.test.assertEquals

import io.micronaut.core.type.Argument
import io.micronaut.test.extensions.junit5.annotation.MicronautTest

import io.micronaut.http.MediaType
import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpRequest
import io.micronaut.http.client.HttpClient
import io.micronaut.http.client.annotation.Client
import io.micronaut.http.client.exceptions.HttpClientResponseException

import com.bed.cordato.core.factories.LIVE_TOKEN
import com.bed.cordato.core.factories.SESSION_PERSON_ID
import com.bed.cordato.core.infrastructure.http.responses.DataResponse
import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse

import com.bed.cordato.features.identity.factories.person
import com.bed.cordato.features.identity.domain.errors.UpdateNameError
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.infrastructure.http.responses.PersonResponse

import com.bed.cordato.features.identity.application.driving.results.UpdateNameResult
import com.bed.cordato.features.identity.application.driving.commands.UpdateNameCommand
import com.bed.cordato.features.identity.application.driving.use_cases.UpdateNameUseCase


private const val DEAD_TOKEN = "dead-token"

/**
 * End-to-end cover of `PATCH /persons/me/name` through the edge guard (filter + binder), the edge Bean Validation,
 * and the neutral error contract. The [UpdateNameUseCase] is a mock (wired globally by
 * [com.bed.cordato.features.identity.factories.UpdateNameUseCaseMockFactory]) so each sealed outcome can be
 * driven — mirroring how [AuthenticationControllerTest] mocks the sign-up use case. The `422` domain-error
 * mapping is only reachable this way: the edge validation deliberately covers the same name rule, so a
 * well-formed body never reaches the domain's `InvalidName`.
 */
@MicronautTest
class PersonUpdateNameControllerTest {

    @Inject
    lateinit var useCase: UpdateNameUseCase

    @Inject
    @field:Client("/")
    lateinit var client: HttpClient

    @BeforeTest
    fun reset() = clearMocks(useCase)

    private fun patch(body: Any, authorization: String? = null): HttpRequest<Any> {
        val request = HttpRequest.PATCH<Any>("/v1/persons/me/name", body)
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun reject(body: Any, authorization: String? = null): HttpClientResponseException =
        try {
            client.toBlocking().exchange(patch(body, authorization), String::class.java)
            error("Expected the request to be refused with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    @Test
    fun `a live session with a valid name returns 200 with the updated person and no password material`() {
        val command = slot<UpdateNameCommand>()
        every { useCase(capture(command)) } returns
            UpdateNameResult.Success(person(id = SESSION_PERSON_ID, name = "Bob", hash = "bcrypt:leaky"))

        val response = client.toBlocking().exchange(
            patch(mapOf("name" to "Bob"), "Bearer $LIVE_TOKEN"),
            Argument.of(DataResponse::class.java, PersonResponse::class.java),
        )

        assertEquals(HttpStatus.OK, response.status)
        val body = response.body()!!.data as PersonResponse
        assertEquals("Bob", body.name)
        assertEquals(SESSION_PERSON_ID, body.id)
        assertEquals("Bob", command.captured.name)
        assertEquals(SESSION_PERSON_ID, command.captured.personId)

        val raw = client.toBlocking().retrieve(patch(mapOf("name" to "Bob"), "Bearer $LIVE_TOKEN"), String::class.java)
        assertFalse(raw.contains("hash"), "response leaked a hash field: $raw")
        assertFalse(raw.contains("bcrypt"), "response leaked the hash value: $raw")
    }

    @Test
    fun `a blank name fails edge validation with 400 without invoking the use case`() {
        val exception = reject(mapOf("name" to ""), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val errors = exception.response.getBody(ErrorsResponse::class.java).get().errors
        verify(exactly = 0) { useCase(any()) }
        assertTrue(errors.all { it.code == "INVALID_REQUEST" })
        assertTrue(errors.any { it.source?.field == "name" }, "$errors")
    }

    @Test
    fun `an over-length name fails edge validation with 400 without invoking the use case`() {
        val tooLong = "a".repeat(NameValueObject.MAX_LENGTH + 1)

        val exception = reject(mapOf("name" to tooLong), "Bearer $LIVE_TOKEN")

        verify(exactly = 0) { useCase(any()) }
        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        assertEquals("INVALID_REQUEST", exception.response.getBody(ErrorsResponse::class.java).get().errors.single().code)
    }

    @Test
    fun `a missing name field is rejected with 400 in the shared shape without invoking the use case`() {
        val exception = reject(mapOf("other" to "x"), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        verify(exactly = 0) { useCase(any()) }
        assertEquals(null, item.source)
        assertEquals("MALFORMED_REQUEST", item.code)
    }

    @Test
    fun `a non-JSON body is rejected with 400 in the shared shape without invoking the use case`() {
        val request = HttpRequest.PATCH("/v1/persons/me/name", "not-json")
            .contentType(MediaType.APPLICATION_JSON)
            .header("Authorization", "Bearer $LIVE_TOKEN")

        val exception = try {
            client.toBlocking().exchange(request, String::class.java)
            error("Expected the request to be refused")
        } catch (exception: HttpClientResponseException) {
            exception
        }

        verify(exactly = 0) { useCase(any()) }
        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        assertEquals("MALFORMED_REQUEST", exception.response.getBody(ErrorsResponse::class.java).get().errors.single().code)
    }

    @Test
    fun `a name rejected by the domain maps to a neutral 422`() {
        every { useCase(any()) } returns UpdateNameResult.Failure(UpdateNameError.InvalidName)

        val exception = reject(mapOf("name" to "Bob"), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals("INVALID_NAME", item.code)
        assertEquals(null, item.source)
    }

    @Test
    fun `no token is refused with a neutral 401 before the use case runs`() {
        val exception = reject(mapOf("name" to "Bob"))

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        verify(exactly = 0) { useCase(any()) }
        assertEquals(null, item.source)
        assertEquals("UNAUTHENTICATED", item.code)
    }

    @Test
    fun `an unresolvable token is refused with a neutral 401 before the use case runs`() {
        val exception = reject(mapOf("name" to "Bob"), "Bearer $DEAD_TOKEN")

        verify(exactly = 0) { useCase(any()) }
        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        assertEquals("UNAUTHENTICATED", exception.response.getBody(ErrorsResponse::class.java).get().errors.single().code)
    }

    @Test
    fun `an orphan session collapses into the same neutral 401`() {
        every { useCase(any()) } returns UpdateNameResult.Failure(UpdateNameError.PersonNotFound)

        val exception = reject(mapOf("name" to "Bob"), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals(null, item.source)
        assertEquals("UNAUTHENTICATED", item.code)
    }

    @Test
    fun `the orphan-session 401 is byte-indistinguishable from an invalid-token 401`() {
        every { useCase(any()) } returns UpdateNameResult.Failure(UpdateNameError.PersonNotFound)

        val orphan = reject(mapOf("name" to "Bob"), "Bearer $LIVE_TOKEN")
        val invalid = reject(mapOf("name" to "Bob"), "Bearer $DEAD_TOKEN")

        assertEquals(invalid.status, orphan.status)
        assertEquals(
            invalid.response.getBody(String::class.java).get(),
            orphan.response.getBody(String::class.java).get(),
            "orphan-session and invalid-token 401 bodies differ",
        )
    }
}
