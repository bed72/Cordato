package com.bed.cordato.features.expense.infrastructure.repositories.mappers

import com.bed.cordato.core.domain.value_objects.MoneyValueObject

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.domain.value_objects.ExpenseDateValueObject
import com.bed.cordato.features.expense.domain.value_objects.DescriptionValueObject

import com.bed.cordato.core.infrastructure.persistence.models.tables.records.ExpenseRecord

/**
 * Translates between the domain [ExpenseEntity] and the jOOQ-generated [ExpenseRecord] at the infrastructure
 * boundary, as `internal` extension functions so call sites read fluently (`expense.toRecord()` /
 * `record.toEntity()`). Value objects are unwrapped to their columns on the way out (the amount to its integer
 * `amount_cents`, the date to `spent_on`, the optional description to a nullable column) and re-validated on
 * the way in. The generated record type never escapes infrastructure — only entities cross back into
 * application.
 */
internal fun ExpenseEntity.toRecord(): ExpenseRecord = ExpenseRecord().also { record ->
    record.id = id
    record.personId = personId
    record.spentOn = date.value
    record.amountCents = amount.cents
    record.description = description?.value
}

/**
 * Rebuilds an [ExpenseEntity] from a stored row. The amount/description are trusted (they were validated
 * before they were ever written), so a value that no longer parses is a data-integrity fault, surfaced loudly
 * rather than silently dropped. The date is intrinsically always valid.
 */
internal fun ExpenseRecord.toEntity(): ExpenseEntity = ExpenseEntity(
    id = id,
    personId = personId,
    date = ExpenseDateValueObject.of(spentOn),
    amount = checkNotNull(MoneyValueObject.of(amountCents)) { "Stored expense amount is invalid: $amountCents" },
    description = description?.let {
        checkNotNull(DescriptionValueObject.of(it)) { "Stored expense description is invalid: $it" }
    },
)
