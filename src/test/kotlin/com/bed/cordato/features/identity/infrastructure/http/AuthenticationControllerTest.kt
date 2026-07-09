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

import io.micronaut.test.extensions.junit5.annotation.MicronautTest

import io.micronaut.http.MediaType
import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpRequest
import io.micronaut.http.client.HttpClient
import io.micronaut.http.client.annotation.Client
import io.micronaut.http.client.exceptions.HttpClientResponseException

import com.bed.cordato.core.factories.session
import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse

import com.bed.cordato.features.identity.application.driving.results.SignUpResult
import com.bed.cordato.features.identity.application.driving.results.SignInResult
import com.bed.cordato.features.identity.application.driving.use_cases.SignUpUseCase
import com.bed.cordato.features.identity.application.driving.use_cases.SignInUseCase

import com.bed.cordato.features.identity.domain.errors.SignUpError
import com.bed.cordato.features.identity.domain.errors.SignInError
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.domain.value_objects.PasswordValueObject

import com.bed.cordato.features.identity.factories.person
import com.bed.cordato.features.identity.factories.signUpRequestBody
import com.bed.cordato.features.identity.factories.signInRequestBody

import com.bed.cordato.features.identity.infrastructure.http.responses.PersonResponse
import com.bed.cordato.features.identity.infrastructure.http.responses.SignInResponse

@MicronautTest
class AuthenticationControllerTest {

    @Inject
    lateinit var useCase: SignUpUseCase

    @Inject
    lateinit var signInUseCase: SignInUseCase

    @Inject
    @field:Client("/")
    lateinit var client: HttpClient

    @BeforeTest
    fun reset() = clearMocks(useCase, signInUseCase)

    private val validBody = signUpRequestBody()

    private fun postSignUp(body: Any): HttpClientResponseException = assertThrows {
        client.toBlocking().exchange(HttpRequest.POST("/v1/authentication/sign-up", body), String::class.java)
    }

    private fun postSignIn(body: Any): HttpClientResponseException = assertThrows {
        client.toBlocking().exchange(HttpRequest.POST("/v1/authentication/sign-in", body), String::class.java)
    }

    private fun postSignUp(body: Any, language: String): HttpClientResponseException = assertThrows {
        client.toBlocking().exchange(
            HttpRequest.POST("/v1/authentication/sign-up", body).header("Accept-Language", language),
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
            HttpRequest.POST("/v1/authentication/sign-up", validBody),
            PersonResponse::class.java,
        )

        assertEquals(HttpStatus.CREATED, response.status)
        val body = response.body()!!
        assertEquals("Alice", body.name)
        assertEquals("person-1", body.id)
        assertEquals("alice@example.com", body.email)

        val raw = client.toBlocking().retrieve(HttpRequest.POST("/v1/authentication/sign-up", validBody), String::class.java)
        assertFalse(raw.contains("hash"), "response leaked a hash field: $raw")
        assertFalse(raw.contains("bcrypt"), "response leaked the hash value: $raw")
    }

    @Test
    fun `missing required field is rejected with 400 in the shared shape without invoking the use case`() {
        val exception = postSignUp(mapOf("name" to "Alice", "email" to "alice@example.com"))

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertTrue(body.errors.isEmpty())
        verify(exactly = 0) { useCase(any()) }
        assertEquals("MALFORMED_REQUEST", body.code)
    }

    @Test
    fun `multiple invalid fields are each reported in errors without invoking the use case`() {
        val exception = postSignUp(mapOf("name" to "", "email" to "not-an-email", "password" to "x"))

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        verify(exactly = 0) { useCase(any()) }
        assertEquals("INVALID_REQUEST", body.code)
        assertEquals(setOf("name", "email", "password"), body.errors.map { it.field }.toSet())
    }

    @Test
    fun `blank name fails edge validation with 400 without invoking the use case`() {
        val exception = postSignUp(validBody + ("name" to ""))

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(String::class.java).get()
        verify(exactly = 0) { useCase(any()) }
        assertTrue(body.contains("nome"), body)
        assertTrue(body.contains("INVALID_REQUEST"), body)
    }

    @Test
    fun `over-length name fails edge validation with 400 without invoking the use case`() {
        val tooLong = "a".repeat(NameValueObject.MAX_LENGTH + 1)

        val exception = postSignUp(validBody + ("name" to tooLong))

        verify(exactly = 0) { useCase(any()) }
        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        assertTrue(exception.response.getBody(String::class.java).get().contains("INVALID_REQUEST"))
    }

    @Test
    fun `malformed e-mail fails edge validation with 400 without invoking the use case`() {
        val exception = postSignUp(validBody + ("email" to "not-an-email"))

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(String::class.java).get()
        verify(exactly = 0) { useCase(any()) }
        assertTrue(body.contains("e-mail"), body)
        assertTrue(body.contains("INVALID_REQUEST"), body)
        assertFalse(body.contains("^["), "leaked the validation regex: $body")
    }

    @Test
    fun `short password fails edge validation with 400 stating the minimum length`() {
        val short = "a".repeat(PasswordValueObject.MIN_LENGTH - 1)

        val exception = postSignUp(validBody + ("password" to short))

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(String::class.java).get()
        verify(exactly = 0) { useCase(any()) }
        assertTrue(body.contains("INVALID_REQUEST"), body)
        assertTrue(body.contains("${PasswordValueObject.MIN_LENGTH}"), body)
    }

    @Test
    fun `non-JSON body is rejected with 400 in the shared shape without invoking the use case`() {
        val exception = assertThrows {
            client.toBlocking().exchange(
                HttpRequest.POST("/v1/authentication/sign-up", "not-json").contentType(MediaType.APPLICATION_JSON),
                String::class.java,
            )
        }

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertTrue(body.errors.isEmpty())
        verify(exactly = 0) { useCase(any()) }
        assertEquals("MALFORMED_REQUEST", body.code)
    }

    @Test
    fun `empty body is rejected with 400 in the shared shape without invoking the use case`() {
        val exception = assertThrows {
            client.toBlocking().exchange(
                HttpRequest.POST("/v1/authentication/sign-up", "").contentType(MediaType.APPLICATION_JSON),
                String::class.java,
            )
        }

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertTrue(body.errors.isEmpty())
        verify(exactly = 0) { useCase(any()) }
        assertEquals("MALFORMED_REQUEST", body.code)
    }

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

        assertTrue(body.contains("SIGNUP_REJECTED"))
        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        assertFalse(body.contains("em uso"), "confirmed the e-mail is in use: $body")
        assertFalse(body.contains("alice@example.com"), "leaked the attempted e-mail: $body")
        assertFalse(body.contains("cadastrado"), "confirmed the e-mail is registered: $body")
    }

    @Test
    fun `unknown Accept-Language falls back to the pt-BR message on a domain error`() {
        every { useCase(any()) } returns SignUpResult.Failure(SignUpError.InvalidName)

        val exception = postSignUp(validBody, language = "fr-FR")

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        val body = exception.response.getBody(String::class.java).get()
        assertTrue(body.contains("INVALID_NAME"), body)
        assertTrue(body.contains("O nome informado é inválido."), body)
    }

    @Test
    fun `unknown Accept-Language falls back to the pt-BR message on edge validation`() {
        val exception = postSignUp(validBody + ("name" to ""), language = "fr-FR")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        verify(exactly = 0) { useCase(any()) }
        assertEquals("INVALID_REQUEST", body.code)
        assertEquals("A requisição contém campos inválidos.", body.message)
        assertTrue(body.errors.any { it.field == "name" && it.message == "O nome é obrigatório." }, "$body")
    }

    @Test
    fun `successful sign-in returns 200 with the opaque token and its expiry`() {
        every { signInUseCase(any()) } returns SignInResult.Success(session(), token = "raw-token")

        val response = client.toBlocking().exchange(
            HttpRequest.POST("/v1/authentication/sign-in", signInRequestBody()),
            SignInResponse::class.java,
        )

        assertEquals(HttpStatus.OK, response.status)
        val body = response.body()!!
        assertEquals("raw-token", body.token)
        assertEquals(session().expiresAt, body.expiresAt)

        val raw = client.toBlocking().retrieve(HttpRequest.POST("/v1/authentication/sign-in", signInRequestBody()), String::class.java)
        assertTrue(raw.contains("expires_at"), "response is not snake_case: $raw")
        assertFalse(raw.contains("expiresAt"), "response leaked a camelCase key: $raw")
    }

    @Test
    fun `invalid credentials map to a neutral 401 revealing neither the factor nor the e-mail`() {
        every { signInUseCase(any()) } returns SignInResult.Failure(SignInError.InvalidCredentials)

        val exception = postSignIn(signInRequestBody())
        val body = exception.response.getBody(ErrorResponse::class.java).get()

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        assertEquals("UNAUTHENTICATED", body.code)
        assertTrue(body.errors.isEmpty())
        assertFalse(body.message.contains("alice@example.com"), "leaked the attempted e-mail: $body")
    }

    @Test
    fun `blank e-mail fails edge presence validation with 400 without invoking the use case`() {
        val exception = postSignIn(signInRequestBody() + ("email" to ""))

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        verify(exactly = 0) { signInUseCase(any()) }
        assertEquals("INVALID_REQUEST", body.code)
        assertTrue(body.errors.any { it.field == "email" }, "$body")
    }

    @Test
    fun `blank password fails edge presence validation with 400 without invoking the use case`() {
        val exception = postSignIn(signInRequestBody() + ("password" to ""))

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        verify(exactly = 0) { signInUseCase(any()) }
        assertEquals("INVALID_REQUEST", body.code)
        assertTrue(body.errors.any { it.field == "password" }, "$body")
    }

    @Test
    fun `missing field is rejected with 400 in the shared shape without invoking the use case`() {
        val exception = postSignIn(mapOf("email" to "alice@example.com"))

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val body = exception.response.getBody(ErrorResponse::class.java).get()
        assertTrue(body.errors.isEmpty())
        verify(exactly = 0) { signInUseCase(any()) }
        assertEquals("MALFORMED_REQUEST", body.code)
    }
}
