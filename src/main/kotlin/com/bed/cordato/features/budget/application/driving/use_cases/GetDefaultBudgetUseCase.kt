package com.bed.cordato.features.budget.application.driving.use_cases

import com.bed.cordato.features.budget.application.driven.ports.ExpenseTotalSpentPort
import com.bed.cordato.features.budget.application.driven.ports.ExpenseSpentAmountPort
import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository
import com.bed.cordato.features.budget.application.driving.commands.GetDefaultBudgetCommand

/**
 * Reads the authenticated actor's default budget ("no budget"): the total spent, in cents, on expenses
 * that fall outside the period of every one of the actor's own live budgets. There is no entity behind
 * this view — it's a fabricated grouping that always "exists" — so unlike [GetActiveBudgetUseCase], it
 * returns `Long` directly, no sealed `Result`/`Error` and no virtual object: summing has no honest domain
 * failure branch, and "not existing" doesn't apply here.
 *
 * The calculation (design.md decision 1) is `totalSpent(person) - Σ spentInRange(person, budget.period)`
 * for every live budget of the person: the total is asked once via [ExpenseTotalSpentPort], then each live
 * budget's own spend (via the existing [ExpenseSpentAmountPort]) is subtracted out. The non-overlap
 * invariant enforced at budget-creation time guarantees a person's live budgets never share even a
 * boundary day, so this subtraction never double-counts an expense and never fails to exclude one that
 * belongs to a live budget.
 *
 * The owner is `command.personId`, resolved by the edge from the authenticated actor, so a person can only
 * ever read their own default budget. The public `invoke` signature is the driving (primary) side of this
 * context.
 */
class GetDefaultBudgetUseCase(
    private val repository: BudgetRepository,
    private val expenseTotalSpentPort: ExpenseTotalSpentPort,
    private val expenseSpentAmountPort: ExpenseSpentAmountPort,
) {
    operator fun invoke(command: GetDefaultBudgetCommand): Long {
        val total = expenseTotalSpentPort(command.personId)

        val spentWithinLiveBudgets = repository.findAllLiveBudgets(command.personId)
            .sumOf { budget -> expenseSpentAmountPort(command.personId, budget.period.startDate, budget.period.endDate) }

        return total - spentWithinLiveBudgets
    }
}
