package com.bed.cordato.features.budget.application.driven.ports

import java.time.LocalDate

/**
 * Anti-Corruption Layer port (ADR 0013): the only way `budget`'s application/domain may ask about spending,
 * phrased entirely in budget's own vocabulary — "how much, in cents, has [personId] spent between
 * [startDate] and [endDate]". `budget/domain` and `budget/application` never import anything from `expense`
 * beyond this port; `expense` never knows this port (or budget) exists. Implemented by
 * `budget/infrastructure/adapters/ExpenseSpentAmountAdapter`, which calls expense's own public use case
 * in-process.
 */
fun interface ExpenseSpentAmountPort {
    operator fun invoke(personId: String, startDate: LocalDate, endDate: LocalDate): Long
}
