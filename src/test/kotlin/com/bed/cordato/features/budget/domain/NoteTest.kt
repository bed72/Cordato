package com.bed.cordato.features.budget.domain

import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

import com.bed.cordato.features.budget.domain.value_objects.NoteValueObject

internal class NoteTest {

    @Test
    fun `accepts a note and trims it`() {
        val note = NoteValueObject.of("  Viagem  ")

        assertNotNull(note)
        assertEquals("Viagem", note.value)
    }

    @Test
    fun `accepts a note at the maximum length`() {
        val atMax = "a".repeat(NoteValueObject.MAX_LENGTH)

        assertNotNull(NoteValueObject.of(atMax))
    }

    @Test
    fun `rejects a note longer than the maximum`() {
        val tooLong = "a".repeat(NoteValueObject.MAX_LENGTH + 1)

        assertNull(NoteValueObject.of(tooLong))
    }
}
