package com.bed.cordato.features.expense.application.driven.repositories

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity

/**
 * Driven port for expense persistence, seen by the application. Implemented in infrastructure.
 *
 * [create] persists a fully-built [ExpenseEntity]. It returns `Unit`: registering an expense has no
 * caller-relevant alternative outcome — there is no uniqueness constraint to collide with and no "already
 * exists" state — so a `Boolean`/`Outcome` would invent a distinction that doesn't exist. A datastore
 * failure surfaces as an infrastructure exception, never crossing back into the application as a value.
 *
 * [findByPerson] returns every expense owned by [personId], as a [List] (empty when the person has none —
 * never `null`, never an error). Listing one's own expenses has no domain failure branch: absence is a
 * normal, empty success. The order is the adapter's concern (deterministic: most recent first); the
 * application only relies on it being stable.
 */
interface ExpenseRepository {
    fun create(expense: ExpenseEntity)

    fun findByPerson(personId: String): List<ExpenseEntity>
}
