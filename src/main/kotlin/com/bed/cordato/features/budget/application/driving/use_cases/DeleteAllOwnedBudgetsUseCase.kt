package com.bed.cordato.features.budget.application.driving.use_cases

import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository
import com.bed.cordato.features.budget.application.driving.commands.DeleteAllOwnedBudgetsCommand

/**
 * Physically removes every budget owned by an actor, live and already soft-deleted alike — distinct from
 * [DeleteBudgetUseCase], which only soft-deletes a single, owner-selected budget. Exists solely to serve
 * `identity`'s account-deletion cascade (ADR-0013): `identity`'s infrastructure adapter is the only
 * caller of this use case, in-process. It returns `Unit`: there is no caller-relevant alternative outcome
 * — a person owning nothing is a silent no-op, not a failure.
 *
 * It does not re-check the person's active status, and it does not know or care who the caller is, the same
 * stance `expense`'s aggregate use cases already take toward `budget`'s own ACL.
 *
 * The public `invoke` signature is the driving (primary) side of this context.
 */
class DeleteAllOwnedBudgetsUseCase(
    private val repository: BudgetRepository,
) {
    operator fun invoke(command: DeleteAllOwnedBudgetsCommand) {
        repository.deleteAllOwnedBy(command.personId)
    }
}
