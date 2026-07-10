package com.bed.cordato.features.expense.domain.errors

/**
 * Exhaustive set of domain reasons registering an expense can be rejected. Returned from the use case,
 * never thrown, so the compiler forces every consumer to handle each case in a `when`.
 *
 * [InvalidAmount] — the amount is not strictly positive (≤ 0). [FutureDate] — the given date is after today.
 * [InvalidDescription] — a present description exceeds the maximum length. All three map to a scalar `422`.
 */
sealed interface CreateExpenseError {
    data object InvalidAmount : CreateExpenseError

    data object FutureDate : CreateExpenseError

    data object InvalidDescription : CreateExpenseError
}
