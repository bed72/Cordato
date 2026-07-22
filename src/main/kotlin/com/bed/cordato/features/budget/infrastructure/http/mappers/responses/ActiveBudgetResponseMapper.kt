package com.bed.cordato.features.budget.infrastructure.http.mappers.responses

import com.bed.cordato.features.budget.domain.virtual_objects.ActiveBudgetVirtualObject
import com.bed.cordato.features.budget.infrastructure.http.responses.ActiveBudgetResponse

/**
 * Projects an [ActiveBudgetVirtualObject] into its public [ActiveBudgetResponse], as an `internal`
 * extension (`activeBudget.toResponse()`). Unwraps the underlying budget's value objects to their wire
 * types and carries the two derived amounts straight through, unchanged.
 */
internal fun ActiveBudgetVirtualObject.toResponse(): ActiveBudgetResponse = ActiveBudgetResponse(
    id = budget.id,
    note = budget.note?.value,
    endDate = budget.period.endDate,
    startDate = budget.period.startDate,
    amountInCents = budget.amount.cents,
    spentInCents = spentInCents,
    remainingInCents = remainingInCents,
)
