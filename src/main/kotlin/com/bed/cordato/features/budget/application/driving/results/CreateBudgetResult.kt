package com.bed.cordato.features.budget.application.driving.results

import com.bed.cordato.features.budget.domain.entities.BudgetEntity
import com.bed.cordato.features.budget.domain.errors.CreateBudgetError

/**
 * Outcome of creating a budget: either the created [BudgetEntity] or a domain [CreateBudgetError]. Sealed
 * so consumers must handle every case in an exhaustive `when`, with no thrown errors.
 */
sealed interface CreateBudgetResult {
    data class Success(val budget: BudgetEntity) : CreateBudgetResult
    data class Failure(val error: CreateBudgetError) : CreateBudgetResult
}
