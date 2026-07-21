package com.bed.cordato.features.budget.infrastructure.repositories.mappers

import com.bed.cordato.core.domain.value_objects.MoneyValueObject

import com.bed.cordato.features.budget.domain.entities.BudgetEntity
import com.bed.cordato.features.budget.domain.enums.BudgetStatusEnum
import com.bed.cordato.features.budget.domain.value_objects.NoteValueObject
import com.bed.cordato.features.budget.domain.value_objects.BudgetPeriodValueObject

import com.bed.cordato.core.infrastructure.persistence.models.tables.records.BudgetRecord

/**
 * Translates between the domain [BudgetEntity] and the jOOQ-generated [BudgetRecord] at the infrastructure
 * boundary, as `internal` extension functions so call sites read fluently (`budget.toRecord()` /
 * `record.toEntity()`). Value objects are unwrapped to their columns on the way out (the amount to its
 * integer `amount_cents`, the period to `start_date`/`end_date`, the optional note to a nullable column,
 * the status to its name) and re-validated on the way in. The generated record type never escapes
 * infrastructure — only entities cross back into application.
 */
internal fun BudgetEntity.toRecord(): BudgetRecord = BudgetRecord().also { record ->
    record.id = id
    record.note = note?.value
    record.personId = personId
    record.status = status.name
    record.endDate = period.endDate
    record.amountCents = amount.cents
    record.startDate = period.startDate
}

/**
 * Rebuilds a [BudgetEntity] from a stored row. The amount/period/note/status are trusted (they were
 * validated before they were ever written), so a value that no longer parses is a data-integrity fault,
 * surfaced loudly rather than silently dropped.
 */
internal fun BudgetRecord.toEntity(): BudgetEntity = BudgetEntity(
    id = id,
    personId = personId,
    status = BudgetStatusEnum.valueOf(status),
    amount = checkNotNull(MoneyValueObject.of(amountCents)) { "Stored budget amount is invalid: $amountCents" },
    period = checkNotNull(BudgetPeriodValueObject.of(startDate, endDate)) {
        "Stored budget period is invalid: $startDate..$endDate"
    },
    note = note?.let { checkNotNull(NoteValueObject.of(it)) { "Stored budget note is invalid: $it" } },
)
