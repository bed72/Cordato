package com.bed.cordato.features.expense.application.driving.use_cases

import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository
import com.bed.cordato.features.expense.application.driving.commands.DeleteAllOwnedExpensesCommand

/**
 * Physically removes every expense owned by an actor — the first delete capability `expense` gets at all.
 * Exists solely to serve `identity`'s account-deletion cascade (ADR-0013): `identity`'s infrastructure
 * adapter is the only caller of this use case, in-process. It returns `Unit`: there is no caller-relevant
 * alternative outcome — a person owning nothing is a silent no-op, not a failure.
 *
 * It does not re-check the person's active status, and it does not know or care who the caller is, the same
 * stance [SumAllExpensesUseCase] already takes toward `budget`'s own ACL.
 *
 * The public `invoke` signature is the driving (primary) side of this context.
 */
class DeleteAllOwnedExpensesUseCase(
    private val repository: ExpenseRepository,
) {
    operator fun invoke(command: DeleteAllOwnedExpensesCommand) {
        repository.deleteAllOwnedBy(command.personId)
    }
}
