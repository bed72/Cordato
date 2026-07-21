package com.bed.cordato.features.budget.domain.enums

/**
 * The lifecycle state of a budget, mirroring identity's `PersonStatusEnum`. A budget is born [LIVE]; only
 * [LIVE] budgets compete for the non-overlap invariant. There is no path to [DELETED] in this slice (it
 * is reserved for a future removal slice), but the invariant already needs to filter by "live" from the
 * first migration.
 */
enum class BudgetStatusEnum {
    LIVE,
    DELETED,
}
