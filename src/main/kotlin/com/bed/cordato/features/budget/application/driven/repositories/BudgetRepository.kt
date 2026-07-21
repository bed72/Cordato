package com.bed.cordato.features.budget.application.driven.repositories

import java.time.LocalDate

import com.bed.cordato.features.budget.domain.entities.BudgetEntity

/**
 * Driven port for budget persistence, seen by the application. Implemented in infrastructure.
 *
 * [hasOverlappingLiveBudget] answers whether [personId] already has another **live** budget whose period
 * shares any day — inclusive of boundaries — with `[startDate, endDate]`. It is a pure query, resolved
 * entirely in the datastore, never by loading rows for in-memory comparison; a removed (non-live) budget
 * never counts.
 *
 * [create] persists a fully-built [BudgetEntity]. It returns `Unit`: creating a budget has no
 * caller-relevant alternative outcome once the overlap check already passed — there is no uniqueness
 * constraint to collide with — so a `Boolean`/`Outcome` would invent a distinction that doesn't exist. A
 * datastore failure surfaces as an infrastructure exception, never crossing back into the application as a
 * value.
 */
interface BudgetRepository {
    fun hasOverlappingLiveBudget(personId: String, startDate: LocalDate, endDate: LocalDate): Boolean

    fun create(budget: BudgetEntity)
}
