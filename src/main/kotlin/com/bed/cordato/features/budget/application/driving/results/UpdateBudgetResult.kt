package com.bed.cordato.features.budget.application.driving.results

import com.bed.cordato.features.budget.domain.entities.BudgetEntity
import com.bed.cordato.features.budget.domain.errors.UpdateBudgetError

/**
 * Outcome of editing a budget: either the updated [BudgetEntity] or a domain [UpdateBudgetError]. Sealed so
 * consumers must handle every case in an exhaustive `when`, with no thrown errors.
 */
sealed interface UpdateBudgetResult {
    data class Success(val budget: BudgetEntity) : UpdateBudgetResult
    data class Failure(val error: UpdateBudgetError) : UpdateBudgetResult
}
