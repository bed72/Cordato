package com.bed.cordato.features.expense.domain.virtual_objects

import com.bed.cordato.core.domain.virtual_objects.KeysetPageVirtualObject

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.domain.value_objects.ExpenseCursorValueObject

/**
 * A read-only page of an actor's own expenses — core's generic [KeysetPageVirtualObject], specialized to
 * expense's own item and cursor types. [items] is the slice itself (possibly empty); [nextCursor] is the
 * keyset position to continue from, or `null` exactly when this is the last page — there is no honest
 * domain failure branch for listing one's own expenses, so this is the whole result, no sealed
 * `Result`/`Error` alongside it.
 */
typealias ExpensePageVirtualObject = KeysetPageVirtualObject<ExpenseEntity, ExpenseCursorValueObject>
