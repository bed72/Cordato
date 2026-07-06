package com.bed.cordato.features.identity.infrastructure.http

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpRequest
import io.micronaut.http.MediaType
import io.micronaut.http.client.HttpClient
import io.micronaut.http.client.annotation.Client
import io.micronaut.http.client.exceptions.HttpClientResponseException
import io.micronaut.context.annotation.Factory
import io.micronaut.context.annotation.Replaces
import io.micronaut.test.extensions.junit5.annotation.MicronautTest

import io.mockk.mockk
import io.mockk.verify
import io.mockk.every
import io.mockk.clearMocks

import jakarta.inject.Inject
import jakarta.inject.Singleton

import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.BeforeTest

import com.bed.cordato.features.identity.application.results.SignUpResult
import com.bed.cordato.features.identity.application.use_cases.SignUpUseCase

import com.bed.cordato.features.identity.domain.errors.SignUpError
import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject
import com.bed.cordato.features.identity.domain.value_objects.PasswordValueObject

import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse

import com.bed.cordato.features.identity.infrastructure.http.responses.PersonResponse

/**
 * HTTP-layer test for [com.bed.cordato.features.identity.infrastructure.http.controllers.PersonController].
 * Boots the controller behind a real Netty server and drives it with a blocking client, so routing,
 * JSON binding, edge Bean Validation and status codes are exercised for real. [SignUpUseCase] is
 * replaced with a MockK bean (see [SignUpUseCaseMockFactory]), which keeps the assertions focused on
 * the controller and leaves the lazy DataSource unrealized — no PostgreSQL is needed.
 */
@MicronautTest
class PersonControllerTest {

    @Inject
    lateinit var useCase: SignUpUseCase

    @Inject
    @field:Client("/")
    lateinit var client: HttpClient

    @BeforeTest
    fun reset() = clearMocks(useCase)

    private val validBody = mapOf(
        "name" to "Alice",
        "email" to "alice@example.com",
        "password" to "s3cretpw",
    )

    private fun person(hash: String = "bcrypt:super-secret") = PersonEntity(
        id = "person-1",
        hash = hash,
        status = PersonStatusEnum.ACTIVE,
        name = NameValueObject.of("Alice")!!,
        email = EmailValueObject.of("alice@example.com")!!,
    )

    private fun postSignUp(body: Any): HttpClientResponseException = assertThrows {
        client.toBlocking().exchange(HttpRequest.POST("/sign-up", body), String::class.java)
    }

    private fun postSignUp(body: Any, acceptLanguage: String): HttpClientResponseException = assertThrows {
        client.toBlocking().exchange(
            HttpRequest.POST("/sign-up", body).header("Accept-Language", acceptLanguage),
            String::class.java,
        )
    }

    private inline fun assertThrows(block: () -> Unit): HttpClientResponseException =
        try {
            block()
            error("Expected the request to fail with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    @Test
    fun `successful signup returns 201 and a person body with no password material`() {
        every { useCase(any()) } returns SignUpResult.Success(person(hash = "bcrypt:leaky"))

        val response = client.toBlocking().exchange(
            HttpRequest.POST("/sign-up", validBody),
            PersonResponse::class.java,
        )

        assertEquals(HttpStatus.CREATED, response.status)
        val body = response.body()!!
        assertEquals("person-1", body.id)
        assertEquals("Alice", body.name)
        assertEquals("alice@example.com", body.email)

        // The hash must not appear anywhere in the serialized JSON, under any field name.
        val raw = client.toBlocking().retrieve(HttpRequest.POST("/sign-up", validBody), String::class.java)
        assertFalse(raw.contains("hash"), "response leaked a hash field: $raw")
        assertFalse(raw.contains("bcrypt"), "response leaked the hash value: $raw")
    }

    @Test
    fun `missing required field is rejected with 400 in the shared shape without invoking the use case`() {
        val exception = postSignUp(mapOf("name" to "Alice", "email" to "alice@example.com")) // no password

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        // Missing field fails deserialization before Bean Validation, so it is a scalar malformed-body 400.
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("MALFORMED_REQUEST", body.code)
        assertTrue(body.errors.isEmpty())
        verify(exactly = 0) { useCase(any()) }
    }

    @Test
    fun `multiple invalid fields are each reported in errors without invoking the use case`() {
        val exception = postSignUp(mapOf("name" to "", "email" to "not-an-email", "password" to "x"))

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("INVALID_REQUEST", body.code)
        // One item per violated field — not a single concatenated message.
        assertEquals(setOf("name", "email", "password"), body.errors.map { it.field }.toSet())
        verify(exactly = 0) { useCase(any()) }
    }

    @Test
    fun `blank name fails edge validation with 400 without invoking the use case`() {
        val exception = postSignUp(validBody + ("name" to ""))

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(String::class.java).get()
        assertTrue(body.contains("INVALID_REQUEST"), body)
        assertTrue(body.contains("nome"), body)
        verify(exactly = 0) { useCase(any()) }
    }

    @Test
    fun `over-length name fails edge validation with 400 without invoking the use case`() {
        val tooLong = "a".repeat(NameValueObject.MAX_LENGTH + 1)

        val exception = postSignUp(validBody + ("name" to tooLong))

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        assertTrue(exception.response.getBody(String::class.java).get().contains("INVALID_REQUEST"))
        verify(exactly = 0) { useCase(any()) }
    }

    @Test
    fun `malformed e-mail fails edge validation with 400 without invoking the use case`() {
        val exception = postSignUp(validBody + ("email" to "not-an-email"))

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(String::class.java).get()
        assertTrue(body.contains("INVALID_REQUEST"), body)
        assertTrue(body.contains("e-mail"), body)
        // The raw regex must never leak into the client-facing message.
        assertFalse(body.contains("^["), "leaked the validation regex: $body")
        verify(exactly = 0) { useCase(any()) }
    }

    @Test
    fun `short password fails edge validation with 400 stating the minimum length`() {
        val short = "a".repeat(PasswordValueObject.MIN_LENGTH - 1)

        val exception = postSignUp(validBody + ("password" to short))

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(String::class.java).get()
        assertTrue(body.contains("INVALID_REQUEST"), body)
        assertTrue(body.contains("${PasswordValueObject.MIN_LENGTH}"), body)
        verify(exactly = 0) { useCase(any()) }
    }

    @Test
    fun `non-JSON body is rejected with 400 in the shared shape without invoking the use case`() {
        val exception = assertThrows {
            client.toBlocking().exchange(
                HttpRequest.POST("/sign-up", "not-json").contentType(MediaType.APPLICATION_JSON),
                String::class.java,
            )
        }

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("MALFORMED_REQUEST", body.code)
        assertTrue(body.errors.isEmpty())
        verify(exactly = 0) { useCase(any()) }
    }

    @Test
    fun `empty body is rejected with 400 in the shared shape without invoking the use case`() {
        val exception = assertThrows {
            client.toBlocking().exchange(
                HttpRequest.POST("/sign-up", "").contentType(MediaType.APPLICATION_JSON),
                String::class.java,
            )
        }

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("MALFORMED_REQUEST", body.code)
        assertTrue(body.errors.isEmpty())
        verify(exactly = 0) { useCase(any()) }
    }

    // The domain-error → 422 mappings below send a valid-shape body (it passes the edge), so the use
    // case runs and its sealed error is mapped. This is the "edge passed, domain rejected" path that
    // stays reachable even with edge validation — e.g. the normalization gap on e-mail.

    @Test
    fun `invalid e-mail maps to 422`() {
        every { useCase(any()) } returns SignUpResult.Failure(SignUpError.InvalidEmail)

        val exception = postSignUp(validBody)

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        assertTrue(exception.response.getBody(String::class.java).get().contains("INVALID_EMAIL"))
    }

    @Test
    fun `invalid name maps to 422`() {
        every { useCase(any()) } returns SignUpResult.Failure(SignUpError.InvalidName)

        val exception = postSignUp(validBody)

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        assertTrue(exception.response.getBody(String::class.java).get().contains("INVALID_NAME"))
    }

    @Test
    fun `weak password maps to 422 and may state the public minimum length`() {
        every { useCase(any()) } returns SignUpResult.Failure(SignUpError.WeakPassword(minLength = 8))

        val exception = postSignUp(validBody)

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        assertTrue(exception.response.getBody(String::class.java).get().contains("8"))
    }

    @Test
    fun `e-mail already in use maps to a neutral 422 that does not reveal registration`() {
        every { useCase(any()) } returns SignUpResult.Failure(SignUpError.EmailAlreadyInUse)

        val exception = postSignUp(validBody)
        val body = exception.response.getBody(String::class.java).get()

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        assertTrue(body.contains("SIGNUP_REJECTED"))
        // Never echo the attempted e-mail, and never confirm the account exists.
        assertFalse(body.contains("alice@example.com"), "leaked the attempted e-mail: $body")
        assertFalse(body.contains("cadastrado"), "confirmed the e-mail is registered: $body")
        assertFalse(body.contains("em uso"), "confirmed the e-mail is in use: $body")
    }

    // i18n: the message text is resolved by key from the bundle. Without a bundle for the requested
    // locale (only pt-BR exists), resolution falls back to the pt-BR default — it never fails the
    // request. The domain-error path (mapper via MessageResolverPort) and the edge-validation path
    // (Bean Validation interpolator) both resolve against the same bundle, so both fall back.

    @Test
    fun `unknown Accept-Language falls back to the pt-BR message on a domain error`() {
        every { useCase(any()) } returns SignUpResult.Failure(SignUpError.InvalidName)

        val exception = postSignUp(validBody, acceptLanguage = "fr-FR")

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        val body = exception.response.getBody(String::class.java).get()
        assertTrue(body.contains("INVALID_NAME"), body)
        assertTrue(body.contains("O nome informado é inválido."), body)
    }

    @Test
    fun `unknown Accept-Language falls back to the pt-BR message on edge validation`() {
        val exception = postSignUp(validBody + ("name" to ""), acceptLanguage = "fr-FR")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertEquals("INVALID_REQUEST", body.code)
        assertEquals("A requisição contém campos inválidos.", body.message)
        assertTrue(body.errors.any { it.field == "name" && it.message == "O nome é obrigatório." }, "$body")
        verify(exactly = 0) { useCase(any()) }
    }
}

/**
 * Replaces the real [SignUpUseCase] binding (from `IdentityFactory`) with a MockK instance for the
 * HTTP tests. A plain `@Replaces` singleton — not `@MockBean` — because `@MockBean` would wrap the
 * bean in an AOP proxy, which Micronaut can't build over the `final` use-case class. The mock *is*
 * the bean, so injecting [SignUpUseCase] into the test yields the very instance the controller
 * calls; stubs and `verify` apply directly.
 */
@Factory
class SignUpUseCaseMockFactory {

    @Singleton
    @Replaces(SignUpUseCase::class)
    fun signUpUseCase(): SignUpUseCase = mockk()
}
