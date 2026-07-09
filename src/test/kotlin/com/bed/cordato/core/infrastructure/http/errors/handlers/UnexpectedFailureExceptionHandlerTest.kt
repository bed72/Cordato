package com.bed.cordato.core.infrastructure.http.errors.handlers

import io.mockk.mockk
import io.mockk.every

import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.assertFalse
import kotlin.test.assertEquals

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpRequest

import com.bed.cordato.core.application.driven.ports.MessagePort

class UnexpectedFailureExceptionHandlerTest {

    private val messages = mockk<MessagePort> {
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
        assertFalse(body.message.contains("SELECT"), body.message)
        assertFalse(body.message.contains("alice@example.com"), body.message)
        assertFalse(body.message.contains("IllegalStateException"), body.message)
    }
}
