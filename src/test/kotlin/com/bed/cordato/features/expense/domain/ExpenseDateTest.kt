package com.bed.cordato.features.expense.domain

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.assertEquals

import com.bed.cordato.features.expense.domain.value_objects.ExpenseDateValueObject

class ExpenseDateTest {

    @Test
    fun `wraps the given calendar day unchanged`() {
        val day = LocalDate.of(2026, 7, 10)

        assertEquals(day, ExpenseDateValueObject.of(day).value)
    }
}
