package com.bed.cordato.features.expense.infrastructure.repositories.mappers

import java.time.LocalDate

import com.fasterxml.jackson.databind.ObjectMapper

import com.bed.cordato.core.domain.value_objects.MoneyValueObject

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.domain.value_objects.ExpenseDateValueObject
import com.bed.cordato.features.expense.domain.value_objects.DescriptionValueObject

/**
 * Translates a slice of [ExpenseEntity] to/from the compact JSON string [CachingExpenseRepository] stores in
 * Valkey — an infra-only serialization, never a domain concern. A plain [Map]/[List] tree keeps this off
 * POJO reflection (no Jackson Kotlin module needed): [ObjectMapper] serializes/parses generic collections
 * natively. As with [toEntity], a value that no longer parses back into its value object is a data-integrity
 * fault surfaced loudly, not silently dropped — the cache is meant to be a faithful, disposable copy of what
 * the datastore already validated.
 */
private val mapper = ObjectMapper()

internal fun List<ExpenseEntity>.toCacheJson(): String = mapper.writeValueAsString(
    map { expense ->
        mapOf(
            "id" to expense.id,
            "person_id" to expense.personId,
            "amount_cents" to expense.amount.cents,
            "spent_on" to expense.date.value.toString(),
            "description" to expense.description?.value,
        )
    },
)

@Suppress("UNCHECKED_CAST")
internal fun String.toExpenseEntities(): List<ExpenseEntity> {
    val rows = mapper.readValue(this, List::class.java) as List<Map<String, Any?>>

    return rows.map { row ->
        ExpenseEntity(
            id = row.getValue("id") as String,
            personId = row.getValue("person_id") as String,
            date = ExpenseDateValueObject.of(LocalDate.parse(row.getValue("spent_on") as String)),
            amount = checkNotNull(MoneyValueObject.of((row.getValue("amount_cents") as Number).toLong())) {
                "Cached expense amount is invalid: ${row["amount_cents"]}"
            },
            description = (row["description"] as String?)?.let {
                checkNotNull(DescriptionValueObject.of(it)) { "Cached expense description is invalid: $it" }
            },
        )
    }
}
