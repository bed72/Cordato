package com.bed.cordato.features.expense.application.driving.use_cases

import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository
import com.bed.cordato.features.expense.application.driving.commands.SumAllExpensesCommand

/**
 * Sums, in cents, an actor's own expenses, with no date limit. Together with
 * [SumExpensesInRangeUseCase], this is the **only** pair of questions `expense` answers about its own
 * data to anyone outside the context — never an individual expense, never the list of them. It returns
 * the total directly, no sealed `Result`/`Error`: summing has no honest domain failure branch, the same
 * stance as [SumExpensesInRangeUseCase].
 *
 * It does not re-check the person's active status, and it does not know or care who the caller is —
 * `budget` (via its own ACL) calls this in-process, exactly like `expense`'s own driving use cases.
 *
 * The public `invoke` signature is the driving (primary) side of this context.
 */
class SumAllExpensesUseCase(
    private val repository: ExpenseRepository,
) {
    operator fun invoke(command: SumAllExpensesCommand): Long = repository.sumAmount(command.personId)
}
