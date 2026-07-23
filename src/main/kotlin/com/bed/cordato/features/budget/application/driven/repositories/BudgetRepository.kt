package com.bed.cordato.features.budget.application.driven.repositories

import java.time.LocalDate

import com.bed.cordato.features.budget.domain.entities.BudgetEntity

/**
 * Driven port for budget persistence, seen by the application. Implemented in infrastructure.
 *
 * [hasOverlappingLiveBudget] answers whether [personId] already has another **live** budget whose period
 * shares any day — inclusive of boundaries — with `[startDate, endDate]`. It is a pure query, resolved
 * entirely in the datastore, never by loading rows for in-memory comparison; a removed (non-live) budget
 * never counts. [excludeId] is `null` for [create]'s check (nothing to exclude); [update] passes its own
 * `id` so the budget being edited never competes against itself.
 *
 * [create] persists a fully-built [BudgetEntity]. It returns `Unit`: creating a budget has no
 * caller-relevant alternative outcome once the overlap check already passed — there is no uniqueness
 * constraint to collide with — so a `Boolean`/`Outcome` would invent a distinction that doesn't exist. A
 * datastore failure surfaces as an infrastructure exception, never crossing back into the application as a
 * value.
 *
 * [update] persists a fully-built, already-validated [BudgetEntity] over its existing row, located by `id`.
 * Like [create], it returns `Unit` — the use case has already resolved ownership/vivacity via [findById]
 * before calling this.
 *
 * [delete] soft-deletes: it transitions the budget to `DELETED` **only if** [id] exists, belongs to
 * [personId], and is currently live — all three checked by the same write, no separate prior read. Returns
 * whether a row was actually changed, so the use case can tell a genuine removal from a no-op (wrong owner,
 * already removed, or unknown id) without a second query.
 *
 * [findById] answers the [BudgetEntity] for [id], of **any** owner and **any** status, or `null` when [id]
 * matches nothing. It deliberately does not filter by owner or vivacity — that policy belongs to whoever
 * consumes the result in the application, mirroring identity's `PersonRepository.findById`.
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

    fun update(budget: BudgetEntity)

    fun delete(id: String, personId: String): Boolean

    fun findById(id: String): BudgetEntity?

    fun findAllLiveBudgets(personId: String): List<BudgetEntity>

    fun findLiveBudgetCovering(personId: String, date: LocalDate): BudgetEntity?

    fun hasOverlappingLiveBudget(
        personId: String,
        startDate: LocalDate,
        endDate: LocalDate,
        excludeId: String? = null,
    ): Boolean
}
