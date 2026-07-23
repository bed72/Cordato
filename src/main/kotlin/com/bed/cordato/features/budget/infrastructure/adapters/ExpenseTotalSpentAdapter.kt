package com.bed.cordato.features.budget.infrastructure.adapters

import com.bed.cordato.features.budget.application.driven.ports.ExpenseTotalSpentPort

import com.bed.cordato.features.expense.application.driving.commands.SumAllExpensesCommand
import com.bed.cordato.features.expense.application.driving.use_cases.SumAllExpensesUseCase

/**
 * Implements [ExpenseTotalSpentPort] (ADR 0013) by calling expense's public [SumAllExpensesUseCase]
 * in-process — no HTTP hop, since both contexts live in the same deployable. Together with
 * [ExpenseSpentAmountAdapter], this is one of the only two places in `budget` allowed to import an
 * `expense` type: it translates budget's port call into expense's own command/return shape and back, so
 * `budget/domain` and `budget/application` never see `expense` directly.
 */
class ExpenseTotalSpentAdapter(
    private val useCase: SumAllExpensesUseCase,
) : ExpenseTotalSpentPort {

    override fun invoke(personId: String): Long = useCase(SumAllExpensesCommand(personId))
}
