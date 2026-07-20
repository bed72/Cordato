package com.bed.cordato.core.infrastructure.http.responses

import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.assertEquals

import io.micronaut.http.HttpStatus

class ErrorResponsesTest {

    @Test
    fun `badRequest with no sources produces a single scalar item with no source`() {
        val response = badRequest("MALFORMED_REQUEST", "O corpo da requisição está ausente ou é inválido.")

        assertEquals(HttpStatus.BAD_REQUEST, response.status)
        val item = response.body()!!.errors.single()
        assertEquals("400", item.status)
        assertEquals("MALFORMED_REQUEST", item.code)
        assertNull(item.source)
    }

    @Test
    fun `badRequest with multiple sources produces one item per field`() {
        val sources = listOf(ErrorSourceResponse("email"), ErrorSourceResponse("password"))

        val response = badRequest("INVALID_REQUEST", "A requisição contém campos inválidos.", sources)

        val items = response.body()!!.errors
        assertEquals(2, items.size)
        assertEquals(setOf("email", "password"), items.mapNotNull { it.source?.field }.toSet())
        assertTrue(items.all { it.status == "400" && it.code == "INVALID_REQUEST" })
    }

    @Test
    fun `unauthorized produces exactly one scalar item with no source`() {
        val response = unauthorized("UNAUTHENTICATED", "Autenticação necessária.")

        assertEquals(HttpStatus.UNAUTHORIZED, response.status)
        val item = response.body()!!.errors.single()
        assertEquals("401", item.status)
        assertEquals("UNAUTHENTICATED", item.code)
        assertNull(item.source)
    }

    @Test
    fun `unprocessable produces exactly one scalar item with no source`() {
        val response = unprocessable("INVALID_NAME", "O nome informado é inválido.")

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, response.status)
        val item = response.body()!!.errors.single()
        assertEquals("422", item.status)
        assertEquals("INVALID_NAME", item.code)
        assertNull(item.source)
    }

    @Test
    fun `internalError produces exactly one scalar item with no source`() {
        val response = internalError("INTERNAL_ERROR", "Ocorreu um erro inesperado.")

        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.status)
        val item = response.body()!!.errors.single()
        assertEquals("500", item.status)
        assertEquals("INTERNAL_ERROR", item.code)
        assertNull(item.source)
    }
}
