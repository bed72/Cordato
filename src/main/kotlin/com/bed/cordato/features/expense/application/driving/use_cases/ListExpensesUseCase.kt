package com.bed.cordato.features.expense.application.driving.use_cases

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity

import com.bed.cordato.features.expense.application.driving.commands.ListExpensesCommand
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Lists the authenticated actor's own expenses. It returns `List<ExpenseEntity>` **directly** — possibly
 * empty — with no sealed `Result`/`Error`: listing one's own expenses has no honest failure branch, since a
 * person with no expenses is a success with zero items, not a "not found". Same principle as
 * [ExpenseRepository.create] returning `Unit`: don't invent a distinction that doesn't exist.
 *
 * The owner is `command.personId`, resolved by the edge from the authenticated actor, so a person can only
 * list their own expenses. The deterministic order (most recent first, stable tie-break) comes from the
 * repository query, not from here. There is no active-status check: the route is already gated by the live
 * session of core's edge guard, mirroring the register slice.
 *
 * The public `invoke` signature is the driving (primary) side of this context.
 */
class ListExpensesUseCase(
    private val repository: ExpenseRepository,
) {
    operator fun invoke(command: ListExpensesCommand): List<ExpenseEntity> =
        repository.findByPerson(command.personId)
}
