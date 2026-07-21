package com.bed.cordato.features.budget.domain.entities

import com.bed.cordato.core.domain.value_objects.MoneyValueObject

import com.bed.cordato.features.budget.domain.enums.BudgetStatusEnum
import com.bed.cordato.features.budget.domain.value_objects.NoteValueObject
import com.bed.cordato.features.budget.domain.value_objects.BudgetPeriodValueObject

/**
 * A budget — the planned ceiling per date range. [personId] is the owner (identity's anchor id); a budget
 * belongs to exactly one person, always the authenticated actor. [amount] is the exact ceiling (cents,
 * always > 0), [period] the covered date range, [note] an optional annotation, [status] the lifecycle state.
 *
 * There is deliberately **no** reference to an expense in any form, nor any derived value (spent/remaining):
 * whether an expense "belongs" to this budget is answered at read time by comparing its date against
 * [period] — derive-don't-store, mirroring `expense`.
 */
data class BudgetEntity(
    val id: String,
    val personId: String,
    val note: NoteValueObject?,
    val amount: MoneyValueObject,
    val status: BudgetStatusEnum,
    val period: BudgetPeriodValueObject,
)
