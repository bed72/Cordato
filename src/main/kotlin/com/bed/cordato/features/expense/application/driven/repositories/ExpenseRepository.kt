package com.bed.cordato.features.expense.application.driven.repositories

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity

/**
 * Driven port for expense persistence, seen by the application. Implemented in infrastructure.
 *
 * [create] persists a fully-built [ExpenseEntity]. It returns `Unit`: registering an expense has no
 * caller-relevant alternative outcome — there is no uniqueness constraint to collide with and no "already
 * exists" state — so a `Boolean`/`Outcome` would invent a distinction that doesn't exist. A datastore
 * failure surfaces as an infrastructure exception, never crossing back into the application as a value.
 */
interface ExpenseRepository {
    fun create(expense: ExpenseEntity)
}
