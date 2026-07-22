package com.bed.cordato.features.budget.domain.virtual_objects

import com.bed.cordato.features.budget.domain.entities.BudgetEntity

/**
 * The day-to-day "active budget" view (ADR 0001): a live [budget] enriched with [spentInCents] and
 * [remainingInCents], both derived, never persisted, recomputed on every ask. Neither derived value is a
 * [com.bed.cordato.core.domain.value_objects.MoneyValueObject] — that type rejects non-positive amounts,
 * but [spentInCents] can legitimately be `0` and [remainingInCents] can legitimately go negative (an
 * exceeded budget), so both stay plain `Long`.
 */
data class ActiveBudgetVirtualObject(
    val budget: BudgetEntity,
    val spentInCents: Long,
    val remainingInCents: Long,
) {
    companion object {
        /** Assembles the view from the live [budget] and its [spentInCents], deriving the remaining amount. */
        fun of(budget: BudgetEntity, spentInCents: Long): ActiveBudgetVirtualObject = ActiveBudgetVirtualObject(
            budget = budget,
            spentInCents = spentInCents,
            remainingInCents = budget.amount.cents - spentInCents,
        )
    }
}
