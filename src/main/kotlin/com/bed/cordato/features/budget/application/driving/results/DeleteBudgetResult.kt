package com.bed.cordato.features.budget.application.driving.results

import com.bed.cordato.features.budget.domain.entities.BudgetEntity
import com.bed.cordato.features.budget.domain.errors.DeleteBudgetError

/**
 * Outcome of removing a budget: either the now-removed [BudgetEntity] (so the caller can confirm the final
 * state without a second call) or a domain [DeleteBudgetError]. Sealed so consumers must handle every case
 * in an exhaustive `when`, with no thrown errors.
 */
sealed interface DeleteBudgetResult {
    data class Success(val budget: BudgetEntity) : DeleteBudgetResult
    data class Failure(val error: DeleteBudgetError) : DeleteBudgetResult
}
