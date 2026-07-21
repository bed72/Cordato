package com.bed.cordato.features.budget.infrastructure.http.mappers.responses

import com.bed.cordato.features.budget.domain.entities.BudgetEntity
import com.bed.cordato.features.budget.infrastructure.http.responses.BudgetResponse

/**
 * Projects a created [BudgetEntity] into its public [BudgetResponse], as an `internal` extension
 * (`budget.toResponse()`). It unwraps the value objects to their wire types — the amount to its integer
 * cents, the period to its start/end `LocalDate`, the optional note to its string (or null) — and carries
 * no expense reference, mirroring the entity.
 */
internal fun BudgetEntity.toResponse(): BudgetResponse = BudgetResponse(
    id = id,
    note = note?.value,
    endDate = period.endDate,
    startDate = period.startDate,
    amountInCents = amount.cents,
)
