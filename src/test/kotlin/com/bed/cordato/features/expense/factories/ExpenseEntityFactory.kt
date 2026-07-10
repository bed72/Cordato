package com.bed.cordato.features.expense.factories

import java.time.LocalDate

import com.bed.cordato.core.domain.value_objects.MoneyValueObject

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.domain.value_objects.ExpenseDateValueObject
import com.bed.cordato.features.expense.domain.value_objects.DescriptionValueObject

/**
 * Builds a valid [ExpenseEntity] from convenient primitives for tests, mirroring identity's `person(...)`
 * builder — the raw inputs are turned into their value objects so a test states only what it cares about.
 */
fun expense(
    id: String = "expense-1",
    personId: String = "person-1",
    amountInCents: Long = 1_500,
    date: LocalDate = LocalDate.of(2026, 7, 10),
    description: String? = "Café",
): ExpenseEntity = ExpenseEntity(
    id = id,
    personId = personId,
    amount = MoneyValueObject.of(amountInCents)!!,
    date = ExpenseDateValueObject.of(date),
    description = description?.let { DescriptionValueObject.of(it)!! },
)
