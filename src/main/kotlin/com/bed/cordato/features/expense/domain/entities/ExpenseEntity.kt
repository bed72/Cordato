package com.bed.cordato.features.expense.domain.entities

import com.bed.cordato.core.domain.value_objects.MoneyValueObject

import com.bed.cordato.features.expense.domain.value_objects.ExpenseDateValueObject
import com.bed.cordato.features.expense.domain.value_objects.DescriptionValueObject

/**
 * A spend — the atomic fact of the domain: who spent, how much, when, and (optionally) a note. [personId]
 * is the owner (identity's anchor id); an expense belongs to exactly one person, always the authenticated
 * actor. [amount] is exact money (cents, always > 0), [date] the day it happened, [description] optional.
 *
 * There is deliberately **no** reference to a budget in any form: an expense records only the raw fact, and
 * whether it "belongs" to a budget is answered at read time by comparing [date] to a budget's range —
 * derive-don't-store, applied from the origin.
 */
data class ExpenseEntity(
    val id: String,
    val personId: String,
    val amount: MoneyValueObject,
    val date: ExpenseDateValueObject,
    val description: DescriptionValueObject?,
)
