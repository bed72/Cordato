package com.bed.cordato.core.infrastructure.http.errors.handlers

import io.mockk.mockk
import io.mockk.every
import io.mockk.verify

import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.assertFalse
import kotlin.test.assertEquals

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpRequest

import com.bed.cordato.core.application.driven.ports.LoggerPort
import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.domain.value_objects.LoggableValueObject

class UnexpectedFailureExceptionHandlerTest {

    private val messages = mockk<MessagePort> {
        every { this@mockk("error.internal.message", any<Map<String, Any>>()) } returns
            "Ocorreu um erro inesperado. Tente novamente mais tarde."
    }

    private val logger = mockk<LoggerPort>(relaxed = true)

    private val handler = UnexpectedFailureExceptionHandler( logger = logger, messages = messages)

    @Test
    fun `any throwable maps to a neutral 500 that leaks no internal detail`() {
        val leaky = IllegalStateException("SELECT * FROM person WHERE email = 'alice@example.com' failed")

        val response = handler.handle(mockk<HttpRequest<*>>(relaxed = true), leaky)

        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.status)
        val item = response.body()!!.errors.single()
        assertEquals("500", item.status)
        assertEquals("INTERNAL_ERROR", item.code)
        assertFalse(item.message.contains("SELECT"), item.message)
        assertFalse(item.message.contains("alice@example.com"), item.message)
        assertFalse(item.message.contains("IllegalStateException"), item.message)
    }

    @Test
    fun `the failure is logged through LoggerPort with the exception as cause`() {
        val leaky = IllegalStateException("boom")

        handler.handle(mockk<HttpRequest<*>>(relaxed = true), leaky)

        verify {
            logger.error(
                "UnexpectedFailureExceptionHandler",
                any(),
                any<Map<String, LoggableValueObject>>(),
                leaky,
            )
        }
    }
}
