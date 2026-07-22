package com.bed.cordato.features.budget.infrastructure.adapters

import java.time.LocalDate

import com.bed.cordato.features.budget.application.driven.ports.ExpenseSpentAmountPort

import com.bed.cordato.features.expense.application.driving.commands.SumExpensesInRangeCommand
import com.bed.cordato.features.expense.application.driving.use_cases.SumExpensesInRangeUseCase

/**
 * Implements [ExpenseSpentAmountPort] (ADR 0013) by calling expense's public [SumExpensesInRangeUseCase]
 * in-process — no HTTP hop, since both contexts live in the same deployable. This is the **only** place in
 * `budget` allowed to import an `expense` type: it translates budget's port call into expense's own
 * command/return shape and back, so `budget/domain` and `budget/application` never see `expense` directly.
 */
class ExpenseSpentAmountAdapter(
    private val useCase: SumExpensesInRangeUseCase,
) : ExpenseSpentAmountPort {

    override fun invoke(personId: String, startDate: LocalDate, endDate: LocalDate): Long =
        useCase(SumExpensesInRangeCommand(personId, startDate, endDate))
}
