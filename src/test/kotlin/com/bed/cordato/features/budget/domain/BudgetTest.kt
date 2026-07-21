package com.bed.cordato.features.budget.domain

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertEquals

import com.bed.cordato.core.domain.value_objects.MoneyValueObject

import com.bed.cordato.features.budget.domain.entities.BudgetEntity
import com.bed.cordato.features.budget.domain.enums.BudgetStatusEnum
import com.bed.cordato.features.budget.domain.value_objects.NoteValueObject
import com.bed.cordato.features.budget.domain.value_objects.BudgetPeriodValueObject

internal class BudgetTest {

    @Test
    fun `is assembled from its value objects and its owner`() {
        val budget = BudgetEntity(
            id = "budget-1",
            personId = "person-1",
            status = BudgetStatusEnum.LIVE,
            note = NoteValueObject.of("Viagem"),
            amount = MoneyValueObject.of(100_000)!!,
            period = BudgetPeriodValueObject.of(LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 31))!!,
        )

        assertEquals("budget-1", budget.id)
        assertEquals("person-1", budget.personId)
        assertEquals(100_000, budget.amount.cents)
        assertEquals("Viagem", budget.note!!.value)
        assertEquals(BudgetStatusEnum.LIVE, budget.status)
        assertEquals(LocalDate.of(2026, 7, 31), budget.period.endDate)
        assertEquals(LocalDate.of(2026, 7, 1), budget.period.startDate)
    }

    @Test
    fun `carries no note when there is none`() {
        val budget = BudgetEntity(
            note = null,
            id = "budget-1",
            personId = "person-1",
            status = BudgetStatusEnum.LIVE,
            amount = MoneyValueObject.of(100_000)!!,
            period = BudgetPeriodValueObject.of(LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 31))!!,
        )

        assertNull(budget.note)
    }
}
