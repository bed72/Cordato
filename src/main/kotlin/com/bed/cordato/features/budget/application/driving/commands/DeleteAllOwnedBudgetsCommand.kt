package com.bed.cordato.features.budget.application.driving.commands

/**
 * Input for
 * [com.bed.cordato.features.budget.application.driving.use_cases.DeleteAllOwnedBudgetsUseCase]: physically
 * remove every budget owned by [personId]. This is the entry point `identity`'s account-deletion cascade
 * (ADR-0013) is allowed to call — the only public way another context may trigger this operation.
 */
data class DeleteAllOwnedBudgetsCommand(val personId: String)
