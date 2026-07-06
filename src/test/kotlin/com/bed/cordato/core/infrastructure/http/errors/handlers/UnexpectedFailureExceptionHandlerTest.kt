package com.bed.cordato.core.infrastructure.http.errors.handlers

import io.mockk.mockk
import io.mockk.every

import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.assertFalse
import kotlin.test.assertEquals

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpRequest

import com.bed.cordato.core.application.ports.MessageResolverPort

/**
 * Unit test for the catch-all [UnexpectedFailureExceptionHandler]: any throwable becomes a neutral `500`
 * whose body never carries the exception's message or any internal detail — the non-leak invariant. The
 * generic message is resolved from a stubbed [MessageResolverPort].
 */
class UnexpectedFailureExceptionHandlerTest {

    private val messages = mockk<MessageResolverPort> {
        every { this@mockk("error.internal.message", any<Map<String, Any>>()) } returns
            "Ocorreu um erro inesperado. Tente novamente mais tarde."
    }

    private val handler = UnexpectedFailureExceptionHandler(messages)

    @Test
    fun `any throwable maps to a neutral 500 that leaks no internal detail`() {
        val leaky = IllegalStateException("SELECT * FROM person WHERE email = 'alice@example.com' failed")

        val response = handler.handle(mockk<HttpRequest<*>>(relaxed = true), leaky)

        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.status)
        val body = response.body()!!
        assertTrue(body.errors.isEmpty())
        assertEquals("INTERNAL_ERROR", body.code)
        // Neither the exception message, the SQL, nor the attempted e-mail may reach the client body.
        assertFalse(body.message.contains("SELECT"), body.message)
        assertFalse(body.message.contains("alice@example.com"), body.message)
        assertFalse(body.message.contains("IllegalStateException"), body.message)
    }
}
