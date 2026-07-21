package com.bed.cordato.features.budget.domain.errors

/**
 * Exhaustive set of domain reasons creating a budget can be rejected. Returned from the use case, never
 * thrown, so the compiler forces every consumer to handle each case in a `when`.
 *
 * [InvalidAmount] — the amount is not strictly positive (≤ 0). [InvalidPeriod] — the end date is before the
 * start date. [InvalidNote] — a present note exceeds the maximum length. [OverlappingBudget] — the period
 * shares a day (inclusive of boundaries) with another live budget of the same person. All four map to a
 * scalar `422`.
 */
sealed interface CreateBudgetError {
    data object InvalidAmount : CreateBudgetError

    data object InvalidPeriod : CreateBudgetError

    data object InvalidNote : CreateBudgetError

    data object OverlappingBudget : CreateBudgetError
}
