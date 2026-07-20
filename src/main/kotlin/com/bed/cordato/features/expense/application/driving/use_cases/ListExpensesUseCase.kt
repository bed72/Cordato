package com.bed.cordato.features.expense.application.driving.use_cases

import com.bed.cordato.core.domain.virtual_objects.KeysetPageVirtualObject

import com.bed.cordato.features.expense.domain.value_objects.ExpenseCursorValueObject
import com.bed.cordato.features.expense.domain.virtual_objects.ExpensePageVirtualObject

import com.bed.cordato.features.expense.application.driving.commands.ListExpensesCommand
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Lists the authenticated actor's own expenses as a keyset-paginated [ExpensePageVirtualObject]. It fetches
 * `command.limit + 1` items — one more than requested, with no extra `COUNT` — and hands the slicing (decide
 * whether a next page exists, cut the probe row off, derive the cursor) to core's generic
 * [KeysetPageVirtualObject.of], supplying only what's expense-specific: how to turn a kept item's
 * `(spentOn, id)` into an [ExpenseCursorValueObject].
 *
 * It returns the virtual object directly — no sealed `Result`/`Error`: listing one's own expenses has no
 * honest domain failure branch (a person with no expenses is a success with an empty page, not a "not
 * found"), the same stance as [ExpenseRepository.create] returning `Unit`.
 *
 * It does not re-check the person's active status: the route is already gated by the core edge guard's live
 * session, and the deletion race is identity's concern. The owner is `command.personId`, resolved by the edge
 * from the authenticated actor, so a person can only ever list their own expenses. The deterministic,
 * most-recent-first order is the repository's guarantee; this use case only slices the probe row off.
 *
 * The public `invoke` signature is the driving (primary) side of this context.
 */
class ListExpensesUseCase(
    private val repository: ExpenseRepository,
) {
    operator fun invoke(command: ListExpensesCommand): ExpensePageVirtualObject {
        val fetched = repository.findByPerson(command.personId, command.after, command.limit + 1)

        return KeysetPageVirtualObject.of(fetched, command.limit) {
            ExpenseCursorValueObject.of(it.date.value, it.id)
        }
    }
}
