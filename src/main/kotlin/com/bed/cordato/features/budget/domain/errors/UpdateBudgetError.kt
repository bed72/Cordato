package com.bed.cordato.features.budget.domain.errors

/**
 * Exhaustive set of domain reasons editing a budget can be rejected. Returned from the use case, never
 * thrown, so the compiler forces every consumer to handle each case in a `when`.
 *
 * [InvalidAmount]/[InvalidPeriod]/[InvalidNote]/[OverlappingBudget] mirror [CreateBudgetError]'s four
 * validation reasons in spirit (same i18n text), but this is a distinct type — not an alias — so this
 * mapper can also handle [BudgetNotFound] without forcing an exhaustive `when` on `CreateBudgetError` to
 * carry a branch it will never produce. All four map to a scalar `422`.
 *
 * [BudgetNotFound] collapses three situations that are deliberately indistinguishable from the outside: the
 * `id` doesn't exist, it belongs to another person, or it is already removed. Maps to a scalar `404`.
 */
sealed interface UpdateBudgetError {
    data object InvalidNote : UpdateBudgetError

    data object InvalidAmount : UpdateBudgetError

    data object InvalidPeriod : UpdateBudgetError

    data object BudgetNotFound : UpdateBudgetError

    data object OverlappingBudget : UpdateBudgetError
}
