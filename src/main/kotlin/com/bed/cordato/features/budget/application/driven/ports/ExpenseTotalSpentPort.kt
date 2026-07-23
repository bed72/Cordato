package com.bed.cordato.features.budget.application.driven.ports

/**
 * Anti-Corruption Layer port (ADR 0013): the only way `budget`'s application/domain may ask about a
 * person's **total** spending, phrased entirely in budget's own vocabulary — "how much, in cents, has
 * [personId] spent in total, with no date limit". `budget/domain` and `budget/application` never import
 * anything from `expense` beyond this port (and the existing [ExpenseSpentAmountPort]); `expense` never
 * knows this port (or budget) exists. Implemented by
 * `budget/infrastructure/adapters/ExpenseTotalSpentAdapter`, which calls expense's own public use case
 * in-process.
 */
fun interface ExpenseTotalSpentPort {
    operator fun invoke(personId: String): Long
}
