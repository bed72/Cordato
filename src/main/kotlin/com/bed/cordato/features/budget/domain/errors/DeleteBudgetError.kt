package com.bed.cordato.features.budget.domain.errors

/**
 * The single domain reason removing a budget can fail. Returned from the use case, never thrown.
 *
 * [BudgetNotFound] collapses three situations that are deliberately indistinguishable from the outside: the
 * `id` doesn't exist, it belongs to another person, or it is already removed. A `sealed interface` with a
 * lone case (not a bare `object`), mirroring identity's `MeError`, so the result branches the same
 * exhaustive way the rest of the codebase does, and a second reason could only ever be added deliberately.
 */
sealed interface DeleteBudgetError {
    data object BudgetNotFound : DeleteBudgetError
}
