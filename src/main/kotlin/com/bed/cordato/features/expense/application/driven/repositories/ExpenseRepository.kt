package com.bed.cordato.features.expense.application.driven.repositories

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.domain.value_objects.ExpenseCursorValueObject

/**
 * Driven port for expense persistence, seen by the application. Implemented in infrastructure.
 *
 * [create] persists a fully-built [ExpenseEntity]. It returns `Unit`: registering an expense has no
 * caller-relevant alternative outcome — there is no uniqueness constraint to collide with and no "already
 * exists" state — so a `Boolean`/`Outcome` would invent a distinction that doesn't exist. A datastore
 * failure surfaces as an infrastructure exception, never crossing back into the application as a value.
 *
 * [findByPerson] returns a **keyset** slice of the expenses owned by [personId]: at most [limit] items,
 * strictly after [after] when given (the first slice when `null`), as a [List] (empty when there is nothing
 * past that position — never `null`, never an error). Listing one's own expenses has no domain failure
 * branch: absence is a normal, empty success. The order is the adapter's concern (deterministic: most
 * recent first, `(spent_on, id)` desc — the same tuple [after] positions against); the application only
 * relies on it being stable. The port knows nothing of an opaque wire cursor or a response envelope — only
 * the typed keyset position and the limit.
 */
interface ExpenseRepository {
    fun create(expense: ExpenseEntity)

    fun findByPerson(personId: String, after: ExpenseCursorValueObject?, limit: Int): List<ExpenseEntity>
}
