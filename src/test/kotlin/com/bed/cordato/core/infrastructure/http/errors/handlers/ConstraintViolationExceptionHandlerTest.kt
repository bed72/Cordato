package com.bed.cordato.core.infrastructure.http.errors.handlers

import io.mockk.mockk
import io.mockk.every

import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.assertEquals

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpRequest

import jakarta.validation.Path
import jakarta.validation.ConstraintViolation
import jakarta.validation.ConstraintViolationException

class ConstraintViolationExceptionHandlerTest {

    private val handler = ConstraintViolationExceptionHandler()

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
    fun `a single violation becomes one error item with status 400 and source field`() {
        val response = handle(violation(pathOf("signUp", "request", "email"), "O e-mail informado é inválido."))

        assertEquals(HttpStatus.BAD_REQUEST, response.status)
        val item = response.body()!!.errors.single()
        assertEquals("400", item.status)
        assertEquals("email", item.source?.field)
        assertEquals("INVALID_REQUEST", item.code)
        assertEquals("O e-mail informado é inválido.", item.message)
    }

    @Test
    fun `source field is the final path node, not the internal method or argument prefix`() {
        val response = handle(violation(pathOf("signUp", "request", "password"), "A senha deve ter ao menos 8 caracteres."))

        val field = response.body()!!.errors.single().source?.field
        assertEquals("password", field)
    }

    @Test
    fun `N violations produce N error items without concatenating messages`() {
        val response = handle(
            violation(pathOf("signUp", "request", "name"), "O nome é obrigatório."),
            violation(pathOf("signUp", "request", "email"), "O e-mail informado é inválido."),
            violation(pathOf("signUp", "request", "password"), "A senha deve ter ao menos 8 caracteres."),
        )

        val errors = response.body()!!.errors
        assertEquals(3, errors.size)
        assertTrue(errors.any { it.message == "O nome é obrigatório." })
        assertEquals(setOf("name", "email", "password"), errors.mapNotNull { it.source?.field }.toSet())
    }
}
