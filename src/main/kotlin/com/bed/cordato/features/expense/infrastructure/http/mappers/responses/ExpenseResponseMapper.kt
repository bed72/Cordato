package com.bed.cordato.features.expense.infrastructure.http.mappers.responses

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.infrastructure.http.responses.ExpenseResponse

/**
 * Projects a created [ExpenseEntity] into its public [ExpenseResponse], as an `internal` extension
 * (`expense.toResponse()`). It unwraps the value objects to their wire types — the amount to its integer
 * cents, the date to its `LocalDate`, the optional description to its string (or null) — and carries no
 * budget reference, mirroring the entity.
 */
internal fun ExpenseEntity.toResponse(): ExpenseResponse = ExpenseResponse(
    id = id,
    date = date.value,
    amountInCents = amount.cents,
    description = description?.value,
)
