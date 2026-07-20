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

import com.bed.cordato.features.identity.domain.errors.UpdateEmailError
import com.bed.cordato.features.identity.infrastructure.http.responses.PersonResponse

import com.bed.cordato.features.identity.factories.person
import com.bed.cordato.features.identity.application.driving.results.UpdateEmailResult
import com.bed.cordato.features.identity.application.driving.commands.UpdateEmailCommand
import com.bed.cordato.features.identity.application.driving.use_cases.UpdateEmailUseCase

private const val DEAD_TOKEN = "dead-token"

/**
 * End-to-end cover of `PATCH /persons/me/email` through the edge guard (filter + binder), the edge Bean
 * Validation, and the neutral error contract. The [UpdateEmailUseCase] is a mock (wired globally by
 * [com.bed.cordato.features.identity.factories.UpdateEmailUseCaseMockFactory]) so each sealed outcome can be
 * driven — mirroring [PersonUpdateNameControllerTest]. The `422` domain-error mappings are only reachable
 * this way: the edge validation deliberately covers the same e-mail format rule, so a well-formed body never
 * reaches the domain's `InvalidEmail`.
 */
@MicronautTest
class PersonUpdateEmailControllerTest {

    @Inject
    lateinit var useCase: UpdateEmailUseCase

    @Inject
    @field:Client("/")
    lateinit var client: HttpClient

    @BeforeTest
    fun reset() = clearMocks(useCase)

    private fun patch(body: Any, authorization: String? = null): HttpRequest<Any> {
        val request = HttpRequest.PATCH<Any>("/v1/persons/me/email", body)
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun reject(body: Any, authorization: String? = null): HttpClientResponseException =
        try {
            client.toBlocking().exchange(patch(body, authorization), String::class.java)
            error("Expected the request to be refused with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    private fun validBody() = mapOf("email" to "new@example.com", "password" to "super-secret")

    @Test
    fun `a live session with a valid e-mail and password returns 200 with the updated person and no password material`() {
        val command = slot<UpdateEmailCommand>()
        every { useCase(capture(command)) } returns
            UpdateEmailResult.Success(person(id = SESSION_PERSON_ID, rawEmail = "new@example.com", hash = "bcrypt:leaky"))

        val response = client.toBlocking().exchange(
            patch(validBody(), "Bearer $LIVE_TOKEN"),
            Argument.of(DataResponse::class.java, PersonResponse::class.java),
        )

        assertEquals(HttpStatus.OK, response.status)
        val body = response.body()!!.data as PersonResponse
        assertEquals(SESSION_PERSON_ID, body.id)
        assertEquals("new@example.com", body.email)
        assertEquals("new@example.com", command.captured.email)
        assertEquals("super-secret", command.captured.password)
        assertEquals(SESSION_PERSON_ID, command.captured.personId)

        val raw = client.toBlocking().retrieve(patch(validBody(), "Bearer $LIVE_TOKEN"), String::class.java)
        assertFalse(raw.contains("hash"), "response leaked a hash field: $raw")
        assertFalse(raw.contains("bcrypt"), "response leaked the hash value: $raw")
        assertFalse(raw.contains("password"), "response leaked the confirmation password: $raw")
    }

    @Test
    fun `a blank e-mail fails edge validation with 400 without invoking the use case`() {
        val exception = reject(mapOf("email" to "", "password" to "super-secret"), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val errors = exception.response.getBody(ErrorsResponse::class.java).get().errors
        verify(exactly = 0) { useCase(any()) }
        assertTrue(errors.all { it.code == "INVALID_REQUEST" })
        assertTrue(errors.any { it.source?.field == "email" }, "$errors")
    }

    @Test
    fun `a malformed e-mail fails edge validation with 400 without invoking the use case`() {
        val exception = reject(mapOf("email" to "not-an-email", "password" to "super-secret"), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val errors = exception.response.getBody(ErrorsResponse::class.java).get().errors
        verify(exactly = 0) { useCase(any()) }
        assertTrue(errors.all { it.code == "INVALID_REQUEST" })
        assertTrue(errors.any { it.source?.field == "email" }, "$errors")
    }

    @Test
    fun `a blank password fails edge validation with 400 without invoking the use case`() {
        val exception = reject(mapOf("email" to "new@example.com", "password" to ""), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val errors = exception.response.getBody(ErrorsResponse::class.java).get().errors
        verify(exactly = 0) { useCase(any()) }
        assertTrue(errors.all { it.code == "INVALID_REQUEST" })
        assertTrue(errors.any { it.source?.field == "password" }, "$errors")
    }

    @Test
    fun `a missing field is rejected with 400 in the shared shape without invoking the use case`() {
        val exception = reject(mapOf("email" to "new@example.com"), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        verify(exactly = 0) { useCase(any()) }
        assertEquals(null, item.source)
        assertEquals("MALFORMED_REQUEST", item.code)
    }

    @Test
    fun `a non-JSON body is rejected with 400 in the shared shape without invoking the use case`() {
        val request = HttpRequest.PATCH("/v1/persons/me/email", "not-json")
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
    fun `an e-mail rejected by the domain maps to a neutral 422`() {
        every { useCase(any()) } returns UpdateEmailResult.Failure(UpdateEmailError.InvalidEmail)

        val exception = reject(validBody(), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals(null, item.source)
        assertEquals("INVALID_EMAIL", item.code)
    }

    @Test
    fun `an e-mail already in use maps to a generic scalar 422 with no field and no attempted e-mail`() {
        every { useCase(any()) } returns UpdateEmailResult.Failure(UpdateEmailError.EmailAlreadyInUse)

        val exception = reject(validBody(), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        val raw = exception.response.getBody(String::class.java).get()
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals(null, item.source)
        assertEquals("EMAIL_UPDATE_REJECTED", item.code)
        assertFalse(raw.contains("new@example.com"), "conflict body echoed the attempted e-mail: $raw")
    }

    @Test
    fun `no token is refused with a neutral 401 before the use case runs`() {
        val exception = reject(validBody())

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        verify(exactly = 0) { useCase(any()) }
        assertEquals(null, item.source)
        assertEquals("UNAUTHENTICATED", item.code)
    }

    @Test
    fun `an unresolvable token is refused with a neutral 401 before the use case runs`() {
        val exception = reject(validBody(), "Bearer $DEAD_TOKEN")

        verify(exactly = 0) { useCase(any()) }
        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        assertEquals("UNAUTHENTICATED", exception.response.getBody(ErrorsResponse::class.java).get().errors.single().code)
    }

    @Test
    fun `an incorrect confirmation password collapses into the same neutral 401`() {
        every { useCase(any()) } returns UpdateEmailResult.Failure(UpdateEmailError.InvalidCredentials)

        val exception = reject(validBody(), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals(null, item.source)
        assertEquals("UNAUTHENTICATED", item.code)
    }

    @Test
    fun `an orphan session collapses into the same neutral 401`() {
        every { useCase(any()) } returns UpdateEmailResult.Failure(UpdateEmailError.PersonNotFound)

        val exception = reject(validBody(), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals("UNAUTHENTICATED", item.code)
        assertEquals(null, item.source)
    }

    @Test
    fun `wrong password, orphan session and invalid token are byte-indistinguishable 401s`() {
        every { useCase(any()) } returnsMany listOf(
            UpdateEmailResult.Failure(UpdateEmailError.InvalidCredentials),
            UpdateEmailResult.Failure(UpdateEmailError.PersonNotFound),
        )

        val wrongPassword = reject(validBody(), "Bearer $LIVE_TOKEN")
        val orphan = reject(validBody(), "Bearer $LIVE_TOKEN")
        val invalidToken = reject(validBody(), "Bearer $DEAD_TOKEN")

        val wrongPasswordBody = wrongPassword.response.getBody(String::class.java).get()
        val orphanBody = orphan.response.getBody(String::class.java).get()
        val invalidTokenBody = invalidToken.response.getBody(String::class.java).get()

        assertEquals(invalidToken.status, orphan.status)
        assertEquals(invalidToken.status, wrongPassword.status)
        assertEquals(invalidTokenBody, wrongPasswordBody, "wrong-password and invalid-token 401 bodies differ")
        assertEquals(invalidTokenBody, orphanBody, "orphan-session and invalid-token 401 bodies differ")
    }
}
