package com.bed.cordato.features.budget.application.driving.use_cases

import com.bed.cordato.features.budget.domain.errors.DeleteBudgetError

import com.bed.cordato.features.budget.application.driving.results.DeleteBudgetResult
import com.bed.cordato.features.budget.application.driving.commands.DeleteBudgetCommand
import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository

/**
 * Removes (soft-deletes) a live budget of the authenticated actor.
 *
 * [BudgetRepository.delete] resolves ownership and vivacity itself, in the same write — a `false` result
 * collapses "never existed", "already removed" and "belongs to another person" into the same
 * [DeleteBudgetError.BudgetNotFound], so there is no separate `findById` step just to check what the write
 * already checked. On `true`, the budget is re-read via [BudgetRepository.findById] to return the caller
 * the now-removed public view (the response confirms the final state without a second call).
 *
 * The public `invoke` signature is the driving (primary) side of this context.
 */
class DeleteBudgetUseCase(
    private val repository: BudgetRepository,
) {
    operator fun invoke(command: DeleteBudgetCommand): DeleteBudgetResult {
        if (!repository.delete(command.budgetId, command.personId)) {
            return DeleteBudgetResult.Failure(DeleteBudgetError.BudgetNotFound)
        }

        val budget = checkNotNull(repository.findById(command.budgetId)) {
            "Budget ${command.budgetId} vanished right after being deleted"
        }

        return DeleteBudgetResult.Success(budget)
    }
}
