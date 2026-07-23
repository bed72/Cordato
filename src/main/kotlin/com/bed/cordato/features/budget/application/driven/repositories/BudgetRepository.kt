package com.bed.cordato.features.budget.application.driven.repositories

import java.time.LocalDate

import com.bed.cordato.features.budget.domain.entities.BudgetEntity

/**
 * Driven port for budget persistence, seen by the application. Implemented in infrastructure.
 *
 * shares any day — inclusive of boundaries — with `[startDate, endDate]`. It is a pure query, resolved
 * entirely in the datastore, never by loading rows for in-memory comparison; a removed (non-live) budget
 * never counts.
 *
 * [hasOverlappingLiveBudget] answers whether [personId] already has another **live** budget whose period
 * [create] persists a fully-built [BudgetEntity]. It returns `Unit`: creating a budget has no
 * caller-relevant alternative outcome once the overlap check already passed — there is no uniqueness
 * constraint to collide with — so a `Boolean`/`Outcome` would invent a distinction that doesn't exist. A
 * datastore failure surfaces as an infrastructure exception, never crossing back into the application as a
 * value.
 *
 * [findLiveBudgetCovering] answers the **live** budget of [personId] whose period covers [date] — inclusive
 * of both boundaries — resolved entirely in the datastore, `null` when none does. The non-overlap invariant
 * enforced at [create] time guarantees at most one live budget of a person ever covers a given date, so this
 * is a plain lookup, not a "pick one of many" decision.
 *
 * [findAllLiveBudgets] answers **every** live budget of [personId], resolved entirely in the datastore, an
 * empty [List] (never `null`) when the person has none. The order is unspecified — summing spend across
 * these periods is commutative, so no caller depends on a particular order.
 */
interface BudgetRepository {
    fun create(budget: BudgetEntity)

    fun findAllLiveBudgets(personId: String): List<BudgetEntity>

    fun findLiveBudgetCovering(personId: String, date: LocalDate): BudgetEntity?

    fun hasOverlappingLiveBudget(personId: String, startDate: LocalDate, endDate: LocalDate): Boolean
}
