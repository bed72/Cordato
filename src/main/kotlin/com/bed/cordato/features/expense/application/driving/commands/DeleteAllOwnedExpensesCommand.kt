package com.bed.cordato.features.expense.application.driving.commands

/**
 * Input for
 * [com.bed.cordato.features.expense.application.driving.use_cases.DeleteAllOwnedExpensesUseCase]:
 * physically remove every expense owned by [personId]. This is the entry point `identity`'s
 * account-deletion cascade (ADR-0013) is allowed to call — the only public way another context may trigger
 * this operation.
 */
data class DeleteAllOwnedExpensesCommand(val personId: String)
