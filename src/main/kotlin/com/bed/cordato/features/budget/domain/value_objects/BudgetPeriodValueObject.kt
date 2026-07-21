package com.bed.cordato.features.budget.domain.value_objects

import java.time.LocalDate

/**
 * The date range a budget covers — [startDate] and [endDate], both **included**, no time-of-day involved.
 * Carries its own intrinsic invariant (end SHALL NOT be before start), unlike expense's date rule (which
 * depends on the clock), so it lives entirely in this pure value object rather than the use case.
 *
 * Construct via [of], which returns `null` when [endDate] is before [startDate]. A single-day period
 * (start equal to end) is valid.
 */
data class BudgetPeriodValueObject private constructor(val startDate: LocalDate, val endDate: LocalDate) {
    companion object {
        fun of(startDate: LocalDate, endDate: LocalDate): BudgetPeriodValueObject? =
            if (endDate.isBefore(startDate)) null else BudgetPeriodValueObject(startDate, endDate)
    }
}
