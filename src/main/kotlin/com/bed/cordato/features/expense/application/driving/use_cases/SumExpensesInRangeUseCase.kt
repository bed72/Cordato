package com.bed.cordato.features.expense.application.driving.use_cases

import com.bed.cordato.features.expense.application.driving.commands.SumExpensesInRangeCommand
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Sums, in cents, an actor's own expenses within a date range. This is the **only** question `expense`
 * answers about its own data to anyone outside the context — never an individual expense, never the list
 * of them (the README's "não conhece orçamentos... pede apenas um total somado" contract). It returns the
 * total directly, no sealed `Result`/`Error`: summing has no honest domain failure branch — nothing in
 * range is a valid `0`, the same stance as [ExpenseRepository.create] returning `Unit`.
 *
 * It does not re-check the person's active status, and it does not know or care who the caller is —
 * `budget` (via its own ACL) calls this in-process, exactly like `expense`'s own driving use cases.
 *
 * The public `invoke` signature is the driving (primary) side of this context.
 */
class SumExpensesInRangeUseCase(
    private val repository: ExpenseRepository,
) {
    operator fun invoke(command: SumExpensesInRangeCommand): Long =
        repository.sumAmountInRange(command.personId, command.startDate, command.endDate)
}
