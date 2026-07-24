package com.bed.cordato.features.identity.infrastructure.adapters

import com.bed.cordato.features.identity.application.driven.ports.PersonOwnedFinancialsPort

import com.bed.cordato.features.budget.application.driving.commands.DeleteAllOwnedBudgetsCommand
import com.bed.cordato.features.budget.application.driving.use_cases.DeleteAllOwnedBudgetsUseCase

import com.bed.cordato.features.expense.application.driving.commands.DeleteAllOwnedExpensesCommand
import com.bed.cordato.features.expense.application.driving.use_cases.DeleteAllOwnedExpensesUseCase

/**
 * Implements [PersonOwnedFinancialsPort] (ADR 0013) by calling budget's and expense's public
 * [DeleteAllOwnedBudgetsUseCase]/[DeleteAllOwnedExpensesUseCase] in-process — no HTTP hop, since every
 * context lives in the same deployable. This is the **only** place in `identity` allowed to import a
 * `budget` or `expense` type: it translates identity's single "delete everything owned" port call into two
 * calls, one per producing context, so `identity/domain` and `identity/application` never see either
 * context directly. Budgets are removed before expenses, matching [com.bed.cordato.features.identity.
 * application.driving.use_cases.DeleteAccountUseCase]'s ordering decision.
 */
class PersonOwnedFinancialsAdapter(
    private val deleteAllOwnedBudgetsUseCase: DeleteAllOwnedBudgetsUseCase,
    private val deleteAllOwnedExpensesUseCase: DeleteAllOwnedExpensesUseCase,
) : PersonOwnedFinancialsPort {

    override fun invoke(personId: String) {
        deleteAllOwnedBudgetsUseCase(DeleteAllOwnedBudgetsCommand(personId))
        deleteAllOwnedExpensesUseCase(DeleteAllOwnedExpensesCommand(personId))
    }
}
