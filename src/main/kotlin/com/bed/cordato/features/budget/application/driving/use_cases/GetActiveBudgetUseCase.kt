package com.bed.cordato.features.budget.application.driving.use_cases

import java.time.LocalDate
import java.time.ZoneOffset

import com.bed.cordato.core.application.driven.ports.ClockPort

import com.bed.cordato.features.budget.domain.virtual_objects.ActiveBudgetVirtualObject

import com.bed.cordato.features.budget.application.driven.ports.ExpenseSpentAmountPort
import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository
import com.bed.cordato.features.budget.application.driving.commands.GetActiveBudgetCommand

/**
 * Reads the authenticated actor's active budget — the live budget whose period covers today, enriched with
 * the spent/remaining amounts. "Today" is derived from the [ClockPort] at [ZoneOffset.UTC], the same
 * pattern expense's `CreateExpenseUseCase` uses.
 *
 * It returns [ActiveBudgetVirtualObject]`?` directly, no sealed `Result`/`Error`: not having an active
 * budget today is a normal, valid answer — not an honest domain failure — the same stance expense's
 * `ListExpensesUseCase` takes by returning an empty page rather than a "not found".
 *
 * When [BudgetRepository.findLiveBudgetCovering] finds nothing, it returns `null` immediately — the
 * [ExpenseSpentAmountPort] is never called for a person with no active budget. When it finds one, the
 * spent amount is asked for exactly the budget's own period, through the ACL port (ADR 0013), never by
 * reaching into `expense` directly.
 *
 * The owner is `command.personId`, resolved by the edge from the authenticated actor, so a person can only
 * ever read their own active budget. The public `invoke` signature is the driving (primary) side of this
 * context.
 */
class GetActiveBudgetUseCase(
    private val clock: ClockPort,
    private val repository: BudgetRepository,
    private val expenseSpentAmountPort: ExpenseSpentAmountPort,
) {
    operator fun invoke(command: GetActiveBudgetCommand): ActiveBudgetVirtualObject? {
        val today = LocalDate.ofInstant(clock(), ZoneOffset.UTC)
        val budget = repository.findLiveBudgetCovering(command.personId, today) ?: return null

        val spentInCents = expenseSpentAmountPort(command.personId, budget.period.startDate, budget.period.endDate)

        return ActiveBudgetVirtualObject.of(budget, spentInCents)
    }
}
