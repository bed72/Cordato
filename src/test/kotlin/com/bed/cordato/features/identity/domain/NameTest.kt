package com.bed.cordato.features.identity.domain

import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

import com.bed.cordato.features.identity.domain.value_objects.NameValueObject

class NameTest {

    @Test
    fun `accepts a non-blank name and trims it`() {
        val name = NameValueObject.of("  Alice  ")

        assertNotNull(name)
        assertEquals("Alice", name.value)
    }

    @Test
    fun `rejects a blank name`() {
        assertNull(NameValueObject.of(""))
        assertNull(NameValueObject.of("   "))
    }

    @Test
    fun `rejects a name longer than the maximum`() {
        val tooLong = "a".repeat(NameValueObject.MAX_LENGTH + 1)

        assertNull(NameValueObject.of(tooLong))
    }
}
