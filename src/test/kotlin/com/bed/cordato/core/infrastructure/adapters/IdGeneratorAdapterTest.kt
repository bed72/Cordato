package com.bed.cordato.core.infrastructure.adapters

import java.util.UUID

import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals

class IdGeneratorAdapterTest {

    private val generator = IdGeneratorAdapter()

    @Test
    fun `produces distinct non-blank ids`() {
        val first = generator()
        val second = generator()

        assertTrue(first.isNotBlank())
        assertNotEquals(first, second)
    }

    @Test
    fun `produces time-ordered UUID v7 values`() {
        val id = generator()

        assertEquals(7, UUID.fromString(id).version())
    }
}
