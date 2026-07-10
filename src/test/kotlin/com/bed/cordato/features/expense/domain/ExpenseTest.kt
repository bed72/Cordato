package com.bed.cordato.features.expense.domain

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertEquals

import com.bed.cordato.core.domain.value_objects.MoneyValueObject

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.domain.value_objects.ExpenseDateValueObject
import com.bed.cordato.features.expense.domain.value_objects.DescriptionValueObject

class ExpenseTest {

    @Test
    fun `is assembled from its value objects and its owner`() {
        val expense = ExpenseEntity(
            id = "expense-1",
            personId = "person-1",
            amount = MoneyValueObject.of(1_500)!!,
            description = DescriptionValueObject.of("Café"),
            date = ExpenseDateValueObject.of(LocalDate.of(2026, 7, 10)),
        )

        assertEquals("expense-1", expense.id)
        assertEquals(1_500, expense.amount.cents)
        assertEquals("person-1", expense.personId)
        assertEquals("Café", expense.description!!.value)
        assertEquals(LocalDate.of(2026, 7, 10), expense.date.value)
    }

    @Test
    fun `carries no description when there is none`() {
        val expense = ExpenseEntity(
            id = "expense-1",
            personId = "person-1",
            amount = MoneyValueObject.of(1_500)!!,
            date = ExpenseDateValueObject.of(LocalDate.of(2026, 7, 10)),
            description = null,
        )

        assertNull(expense.description)
    }
}
