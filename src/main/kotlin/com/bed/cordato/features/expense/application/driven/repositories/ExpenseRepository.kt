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
 * [findByPerson] returns every expense owned by [personId], as a `List` (never `null`): empty when the
 * person has none. Listing one's own expenses has no failure branch — "no expenses" is a success with zero
 * items, not a "not found" — so there is no `Outcome`/`Result` to reconcile. The order is fixed and
 * deterministic (most recent first, stable tie-break), decided by the implementation, not the caller.
 */
interface ExpenseRepository {
    fun create(expense: ExpenseEntity)
    fun findByPerson(personId: String): List<ExpenseEntity>
}
