package com.bed.cordato.core.infrastructure.http.errors.handlers

import io.mockk.mockk
import io.mockk.every

import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.assertEquals

import io.micronaut.http.HttpRequest
import io.micronaut.http.HttpStatus

import jakarta.validation.Path
import jakarta.validation.ConstraintViolation
import jakarta.validation.ConstraintViolationException

import com.bed.cordato.core.infrastructure.http.responses.FieldErrorResponse
import com.bed.cordato.core.application.ports.MessagePort


/**
 * Unit test for the shared [ConstraintViolationExceptionHandler]: drives it with mocked
 * [ConstraintViolation]s (no server, no real validator) to pin the mapping — one [FieldErrorResponse] per
 * violation, [FieldErrorResponse.field] taken from the *final* node of the property path (never the internal
 * `method.arg` prefix), and no concatenation across fields. The scalar summary is resolved from a stubbed
 * [MessagePort], so the assertions here stay about the mapping shape, not the bundle content.
 */
class ConstraintViolationExceptionHandlerTest {

    private val messages = mockk<MessagePort> {
        every { this@mockk("error.validation.message", any<Map<String, Any>>()) } returns
            "A requisição contém campos inválidos."
    }

    private val handler = ConstraintViolationExceptionHandler(messages)

    private fun node(name: String): Path.Node = mockk { every { this@mockk.name } returns name }

    private fun pathOf(vararg segments: String): Path =
        mockk { every { iterator() } returns segments.map(::node).toMutableList().iterator() }

    private fun violation(path: Path, message: String): ConstraintViolation<*> = mockk {
        every { propertyPath } returns path
        every { this@mockk.message } returns message
    }

    private fun handle(vararg violations: ConstraintViolation<*>) =
        handler.handle(mockk<HttpRequest<*>>(), ConstraintViolationException(violations.toSet()))

    @Test
    fun `a single violation becomes one field error in a 400`() {
        val response = handle(violation(pathOf("signUp", "request", "email"), "O e-mail informado é inválido."))

        assertEquals(HttpStatus.BAD_REQUEST, response.status)
        val body = response.body()!!
        assertEquals("INVALID_REQUEST", body.code)
        assertEquals(listOf(FieldErrorResponse("email", "O e-mail informado é inválido.")), body.errors)
    }

    @Test
    fun `field is the final path node, not the internal method or argument prefix`() {
        val response = handle(violation(pathOf("signUp", "request", "password"), "A senha deve ter ao menos 8 caracteres."))

        val field = response.body()!!.errors.single().field
        assertEquals("password", field)
    }

    @Test
    fun `N violations produce N field errors without concatenating messages`() {
        val response = handle(
            violation(pathOf("signUp", "request", "name"), "O nome é obrigatório."),
            violation(pathOf("signUp", "request", "email"), "O e-mail informado é inválido."),
            violation(pathOf("signUp", "request", "password"), "A senha deve ter ao menos 8 caracteres."),
        )

        val body = response.body()!!
        assertEquals(setOf("name", "email", "password"), body.errors.map { it.field }.toSet())
        // The per-field messages must live in `errors`, never glued into the summary `message`.
        assertTrue(!body.message.contains("nome"), body.message)
        assertTrue(body.errors.any { it.message == "O nome é obrigatório." })
    }
}
