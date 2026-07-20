package com.bed.cordato.core.infrastructure.http.responses

import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertEquals

import io.micronaut.http.HttpStatus

class DataResponsesTest {

    @Test
    fun `ok wraps the item in data with no meta or links by default`() {
        val response = ok("item")

        assertEquals(HttpStatus.OK, response.status)
        val body = response.body()!!
        assertEquals("item", body.data)
        assertNull(body.meta)
        assertNull(body.links)
    }

    @Test
    fun `ok carries meta and links when provided`() {
        val meta = MetaResponse(pagination = PaginationMetaResponse(nextCursor = "cursor-1"))
        val links = LinksResponse(self = "/v1/expenses", next = "/v1/expenses?cursor=cursor-1")

        val response = ok(listOf("a", "b"), meta, links)

        val body = response.body()!!
        assertEquals(meta, body.meta)
        assertEquals(links, body.links)
        assertEquals(listOf("a", "b"), body.data)
    }

    @Test
    fun `created wraps the item in data with 201 and no meta or links`() {
        val response = created("item")

        assertEquals(HttpStatus.CREATED, response.status)
        val body = response.body()!!
        assertNull(body.meta)
        assertNull(body.links)
        assertEquals("item", body.data)
    }
}
