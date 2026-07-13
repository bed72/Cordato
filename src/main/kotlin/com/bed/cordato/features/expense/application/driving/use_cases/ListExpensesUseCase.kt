package com.bed.cordato.features.expense.application.driving.use_cases

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity

import com.bed.cordato.features.expense.application.driving.commands.ListExpensesCommand
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Lists the authenticated actor's own expenses. It returns `List<ExpenseEntity>` directly — no sealed
 * `Result`/`Error`: listing one's own expenses has no honest domain failure branch (a person with no
 * expenses is a success with zero items, not a "not found"), so a one-case sealed type would be ceremony
 * without value, the same stance as [ExpenseRepository.create] returning `Unit`.
 *
 * It does not re-check the person's active status: the route is already gated by the core edge guard's live
 * session, and the deletion race is identity's concern. The owner is `command.personId`, resolved by the edge
 * from the authenticated actor, so a person can only ever list their own expenses. The deterministic,
 * most-recent-first order is the repository's guarantee; the use case is a thin pass-through.
 *
 * The public `invoke` signature is the driving (primary) side of this context.
 */
class ListExpensesUseCase(
    private val repository: ExpenseRepository,
) {
    operator fun invoke(command: ListExpensesCommand): List<ExpenseEntity> =
        repository.findByPerson(command.personId)
}
