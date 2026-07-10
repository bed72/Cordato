package com.bed.cordato.features.expense.domain

import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

import com.bed.cordato.features.expense.domain.value_objects.DescriptionValueObject

class DescriptionTest {

    @Test
    fun `accepts a description and trims it`() {
        val description = DescriptionValueObject.of("  Almoço  ")

        assertNotNull(description)
        assertEquals("Almoço", description.value)
    }

    @Test
    fun `accepts a description at the maximum length`() {
        val atMax = "a".repeat(DescriptionValueObject.MAX_LENGTH)

        assertNotNull(DescriptionValueObject.of(atMax))
    }

    @Test
    fun `rejects a description longer than the maximum`() {
        val tooLong = "a".repeat(DescriptionValueObject.MAX_LENGTH + 1)

        assertNull(DescriptionValueObject.of(tooLong))
    }
}
