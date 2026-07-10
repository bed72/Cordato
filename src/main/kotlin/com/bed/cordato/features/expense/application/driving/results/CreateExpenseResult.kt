package com.bed.cordato.features.expense.application.driving.results

import com.bed.cordato.features.expense.domain.errors.CreateExpenseError
import com.bed.cordato.features.expense.domain.entities.ExpenseEntity

/**
 * Outcome of registering an expense: either the created [ExpenseEntity] or a domain [CreateExpenseError].
 * Sealed so consumers must handle every case in an exhaustive `when`, with no thrown errors.
 */
sealed interface CreateExpenseResult {
    data class Failure(val error: CreateExpenseError) : CreateExpenseResult
    data class Success(val expense: ExpenseEntity) : CreateExpenseResult
}
