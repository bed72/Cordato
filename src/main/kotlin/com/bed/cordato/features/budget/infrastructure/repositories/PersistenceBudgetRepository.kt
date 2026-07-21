package com.bed.cordato.features.budget.infrastructure.repositories

import java.time.LocalDate

import org.jooq.DSLContext

import com.bed.cordato.core.infrastructure.persistence.models.Tables.BUDGET

import com.bed.cordato.features.budget.domain.enums.BudgetStatusEnum
import com.bed.cordato.features.budget.domain.entities.BudgetEntity
import com.bed.cordato.features.budget.infrastructure.repositories.mappers.toRecord
import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository

/**
 * Durable [BudgetRepository] on PostgreSQL via jOOQ. Creating a budget is a plain INSERT: there is no
 * uniqueness constraint and no "already exists" state to reconcile (the non-overlap invariant is enforced
 * by [hasOverlappingLiveBudget] in the application, not by a database constraint — see design.md risks), so
 * a genuine datastore failure propagates as an infrastructure exception; the record type never escapes this
 * layer (the mapper does the translation).
 *
 * [hasOverlappingLiveBudget] resolves the classic closed-interval intersection condition entirely in the
 * database via `EXISTS`: a live budget of [personId] overlaps `[startDate, endDate]` when
 * `startDate <= existing.end_date AND existing.start_date <= endDate` (both sides inclusive, matching the
 * README's boundary-inclusive rule), filtered to [BudgetStatusEnum.LIVE] only.
 */
class PersistenceBudgetRepository(private val dsl: DSLContext) : BudgetRepository {

    override fun hasOverlappingLiveBudget(personId: String, startDate: LocalDate, endDate: LocalDate): Boolean =
        dsl.fetchExists(
            dsl.selectOne()
                .from(BUDGET)
                .where(BUDGET.PERSON_ID.eq(personId))
                .and(BUDGET.STATUS.eq(BudgetStatusEnum.LIVE.name))
                .and(BUDGET.START_DATE.le(endDate))
                .and(BUDGET.END_DATE.ge(startDate)),
        )

    override fun create(budget: BudgetEntity) {
        dsl.insertInto(BUDGET)
            .set(budget.toRecord())
            .execute()
    }
}
