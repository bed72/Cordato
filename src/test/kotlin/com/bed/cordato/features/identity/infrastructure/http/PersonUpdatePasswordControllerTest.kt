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

import io.micronaut.http.MediaType
import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpRequest
import io.micronaut.http.client.HttpClient
import io.micronaut.http.client.annotation.Client
import io.micronaut.test.extensions.junit5.annotation.MicronautTest
import io.micronaut.http.client.exceptions.HttpClientResponseException

import com.bed.cordato.core.factories.LIVE_TOKEN
import com.bed.cordato.core.factories.LIVE_SESSION_ID
import com.bed.cordato.core.factories.SESSION_PERSON_ID
import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse

import com.bed.cordato.features.identity.domain.errors.UpdatePasswordError

import com.bed.cordato.features.identity.factories.person
import com.bed.cordato.features.identity.application.driving.commands.UpdatePasswordCommand
import com.bed.cordato.features.identity.application.driving.results.UpdatePasswordResult
import com.bed.cordato.features.identity.application.driving.use_cases.UpdatePasswordUseCase

import com.bed.cordato.features.identity.infrastructure.http.responses.PersonResponse

private const val DEAD_TOKEN = "dead-token"

/**
 * End-to-end cover of `PATCH /persons/me/password` through the edge guard (filter + binder), the edge Bean
 * Validation, and the neutral error contract. The [UpdatePasswordUseCase] is a mock (wired globally by
 * [com.bed.cordato.features.identity.factories.UpdatePasswordUseCaseMockFactory]) so each sealed outcome can be
 * driven — mirroring [PersonUpdateEmailControllerTest]. The `422` domain-error mappings are only reachable
 * this way: the edge validation deliberately covers the same minimum-length rule, so a well-formed body never
 * reaches the domain's `WeakPassword`.
 */
@MicronautTest
class PersonUpdatePasswordControllerTest {

    @Inject
    lateinit var useCase: UpdatePasswordUseCase

    @Inject
    @field:Client("/")
    lateinit var client: HttpClient

    @BeforeTest
    fun reset() = clearMocks(useCase)

    private fun patch(body: Any, authorization: String? = null): HttpRequest<Any> {
        val request = HttpRequest.PATCH<Any>("/v1/persons/me/password", body)
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun reject(body: Any, authorization: String? = null): HttpClientResponseException =
        try {
            client.toBlocking().exchange(patch(body, authorization), String::class.java)
            error("Expected the request to be refused with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    // Wire contract is snake_case (micronaut.serde.property-naming-strategy=SNAKE_CASE), so body keys are
    // snake_case even though the Kotlin properties (and the validation field names) stay camelCase.
    private fun validBody() = mapOf("current_password" to "current-secret", "new_password" to "new-str0ng-secret")

    @Test
    fun `a live session with a valid current and new password returns 200 with the person and no password material`() {
        val command = slot<UpdatePasswordCommand>()
        every { useCase(capture(command)) } returns
            UpdatePasswordResult.Success(person(id = SESSION_PERSON_ID, hash = "bcrypt:leaky"))

        val response = client.toBlocking().exchange(
            patch(validBody(), "Bearer $LIVE_TOKEN"),
            PersonResponse::class.java,
        )

        assertEquals(HttpStatus.OK, response.status)
        assertEquals(SESSION_PERSON_ID, response.body()!!.id)
        // The command carries the actor's personId AND sessionId (never body-supplied) plus the raw passwords —
        // the sessionId is what lets the use case spare the current session while revoking the others.
        assertEquals(SESSION_PERSON_ID, command.captured.personId)
        assertEquals(LIVE_SESSION_ID, command.captured.sessionId)
        assertEquals("current-secret", command.captured.currentPassword)
        assertEquals("new-str0ng-secret", command.captured.newPassword)

        val raw = client.toBlocking().retrieve(patch(validBody(), "Bearer $LIVE_TOKEN"), String::class.java)
        assertFalse(raw.contains("hash"), "response leaked a hash field: $raw")
        assertFalse(raw.contains("bcrypt"), "response leaked the hash value: $raw")
        assertFalse(raw.contains("secret"), "response leaked a password: $raw")
    }

    @Test
    fun `a blank current password fails edge validation with 400 without invoking the use case`() {
        val exception = reject(mapOf("current_password" to "", "new_password" to "new-str0ng-secret"), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("INVALID_REQUEST", body.code)
        assertTrue(body.errors.any { it.field == "currentPassword" }, "$body")
        verify(exactly = 0) { useCase(any()) }
    }

    @Test
    fun `a new password below the minimum length fails edge validation with 400 without invoking the use case`() {
        val exception = reject(mapOf("current_password" to "current-secret", "new_password" to "short"), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("INVALID_REQUEST", body.code)
        assertTrue(body.errors.any { it.field == "newPassword" }, "$body")
        verify(exactly = 0) { useCase(any()) }
    }

    @Test
    fun `a missing field is rejected with 400 in the shared shape without invoking the use case`() {
        val exception = reject(mapOf("current_password" to "current-secret"), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("MALFORMED_REQUEST", body.code)
        assertTrue(body.errors.isEmpty())
        verify(exactly = 0) { useCase(any()) }
    }

    @Test
    fun `a non-JSON body is rejected with 400 in the shared shape without invoking the use case`() {
        val request = HttpRequest.PATCH("/v1/persons/me/password", "not-json")
            .contentType(MediaType.APPLICATION_JSON)
            .header("Authorization", "Bearer $LIVE_TOKEN")

        val exception = try {
            client.toBlocking().exchange(request, String::class.java)
            error("Expected the request to be refused")
        } catch (exception: HttpClientResponseException) {
            exception
        }

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        assertEquals("MALFORMED_REQUEST", exception.response.getBody(ErrorResponse::class.java).get().code)
        verify(exactly = 0) { useCase(any()) }
    }

    @Test
    fun `a weak new password maps to a specific 422`() {
        every { useCase(any()) } returns UpdatePasswordResult.Failure(UpdatePasswordError.WeakPassword)

        val exception = reject(validBody(), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("WEAK_PASSWORD", body.code)
        assertTrue(body.errors.isEmpty())
    }

    @Test
    fun `a new password equal to the current one maps to a specific 422 sharing the status with weak`() {
        every { useCase(any()) } returns UpdatePasswordResult.Failure(UpdatePasswordError.SamePassword)

        val exception = reject(validBody(), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("SAME_PASSWORD", body.code)
        assertTrue(body.errors.isEmpty())
    }

    @Test
    fun `no token is refused with a neutral 401 before the use case runs`() {
        val exception = reject(validBody())

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("UNAUTHENTICATED", body.code)
        assertTrue(body.errors.isEmpty())
        verify(exactly = 0) { useCase(any()) }
    }

    @Test
    fun `an unresolvable token is refused with a neutral 401 before the use case runs`() {
        val exception = reject(validBody(), "Bearer $DEAD_TOKEN")

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        assertEquals("UNAUTHENTICATED", exception.response.getBody(ErrorResponse::class.java).get().code)
        verify(exactly = 0) { useCase(any()) }
    }

    @Test
    fun `an incorrect current password collapses into the same neutral 401`() {
        every { useCase(any()) } returns UpdatePasswordResult.Failure(UpdatePasswordError.InvalidCredentials)

        val exception = reject(validBody(), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("UNAUTHENTICATED", body.code)
        assertTrue(body.errors.isEmpty())
    }

    @Test
    fun `an orphan session collapses into the same neutral 401`() {
        every { useCase(any()) } returns UpdatePasswordResult.Failure(UpdatePasswordError.PersonNotFound)

        val exception = reject(validBody(), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("UNAUTHENTICATED", body.code)
        assertTrue(body.errors.isEmpty())
    }

    @Test
    fun `wrong current password, orphan session and invalid token are byte-indistinguishable 401s`() {
        every { useCase(any()) } returnsMany listOf(
            UpdatePasswordResult.Failure(UpdatePasswordError.InvalidCredentials),
            UpdatePasswordResult.Failure(UpdatePasswordError.PersonNotFound),
        )

        val wrongPassword = reject(validBody(), "Bearer $LIVE_TOKEN")
        val orphan = reject(validBody(), "Bearer $LIVE_TOKEN")
        val invalidToken = reject(validBody(), "Bearer $DEAD_TOKEN")

        val wrongPasswordBody = wrongPassword.response.getBody(String::class.java).get()
        val orphanBody = orphan.response.getBody(String::class.java).get()
        val invalidTokenBody = invalidToken.response.getBody(String::class.java).get()

        assertEquals(invalidToken.status, wrongPassword.status)
        assertEquals(invalidToken.status, orphan.status)
        assertEquals(invalidTokenBody, wrongPasswordBody, "wrong-password and invalid-token 401 bodies differ")
        assertEquals(invalidTokenBody, orphanBody, "orphan-session and invalid-token 401 bodies differ")
    }
}
