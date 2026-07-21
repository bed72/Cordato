package com.bed.cordato.features.budget.domain

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

import com.bed.cordato.features.budget.domain.value_objects.BudgetPeriodValueObject

internal class BudgetPeriodTest {

    @Test
    fun `accepts a period where the end comes after the start`() {
        val end = LocalDate.of(2026, 7, 31)
        val start = LocalDate.of(2026, 7, 1)

        val period = BudgetPeriodValueObject.of(start, end)

        assertNotNull(period)
        assertEquals(end, period.endDate)
        assertEquals(start, period.startDate)
    }

    @Test
    fun `accepts a single-day period`() {
        val day = LocalDate.of(2026, 7, 1)

        assertNotNull(BudgetPeriodValueObject.of(day, day))
    }

    @Test
    fun `rejects a period where the end comes before the start`() {
        val start = LocalDate.of(2026, 7, 15)
        val end = LocalDate.of(2026, 7, 14)

        assertNull(BudgetPeriodValueObject.of(start, end))
    }
}
