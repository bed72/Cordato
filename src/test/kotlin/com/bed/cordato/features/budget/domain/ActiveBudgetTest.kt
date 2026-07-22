package com.bed.cordato.features.budget.domain

import kotlin.test.Test
import kotlin.test.assertEquals

import com.bed.cordato.features.budget.factories.budget
import com.bed.cordato.features.budget.domain.virtual_objects.ActiveBudgetVirtualObject

internal class ActiveBudgetTest {

    @Test
    fun `remaining is the amount minus the spent amount`() {
        val data = ActiveBudgetVirtualObject.of(budget(amountInCents = 100_000), spentInCents = 45_000)

        assertEquals(45_000, data.spentInCents)
        assertEquals(55_000, data.remainingInCents)
    }

    @Test
    fun `no spending leaves the remaining amount equal to the budget amount`() {
        val data = ActiveBudgetVirtualObject.of(budget(amountInCents = 100_000), spentInCents = 0)

        assertEquals(0, data.spentInCents)
        assertEquals(100_000, data.remainingInCents)
    }

    @Test
    fun `spending past the amount produces a negative remaining, not an error`() {
        val data = ActiveBudgetVirtualObject.of(budget(amountInCents = 100_000), spentInCents = 130_000)

        assertEquals(-30_000, data.remainingInCents)
    }
}
