package com.bed.cordato.features.expense.infrastructure.repositories

import java.time.LocalDate
import java.math.BigDecimal

import org.jooq.DSLContext
import org.jooq.impl.DSL.row
import org.jooq.impl.DSL.sum
import org.jooq.impl.DSL.coalesce

import com.bed.cordato.core.infrastructure.persistence.models.Tables.EXPENSE

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.infrastructure.repositories.mappers.toEntity
import com.bed.cordato.features.expense.infrastructure.repositories.mappers.toRecord
import com.bed.cordato.features.expense.domain.value_objects.ExpenseCursorValueObject
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Durable [ExpenseRepository] on PostgreSQL via jOOQ. Registering an expense is a plain INSERT: there is no
 * uniqueness constraint and no "already exists" state to reconcile, so — unlike identity's signup — there is
 * no datastore conflict to catch and fold into a value. A genuine datastore failure propagates as an
 * infrastructure exception; the record type never escapes this layer (the mapper does the translation).
 *
 * [findByPerson] is a filtered, keyset-paginated SELECT: `person_id` scopes the owner, an optional
 * `(spent_on, id) < (after.spentOn, after.id)` tuple comparison (jOOQ's `row(...).lessThan(row(...))`,
 * evaluated by PostgreSQL as a lexicographic tuple compare) continues strictly past a given position, and
 * `ORDER BY spent_on DESC, id DESC LIMIT ?` does the ordering/cutoff in the database, never in memory. It
 * reuses the `person_id` index from V3 (no new migration). An owner with nothing past the given position
 * yields an empty list, not `null`.
 *
 * [sumAmountInRange] is `SELECT COALESCE(SUM(amount_cents), 0) WHERE person_id = ? AND spent_on BETWEEN ?
 * AND ?` — the aggregate (and the `0`-when-nothing-matches fallback) is resolved entirely by PostgreSQL,
 * never by loading rows to sum in the application.
 *
 * [sumAmount] is the same query without the date filter — `SELECT COALESCE(SUM(amount_cents), 0) WHERE
 * person_id = ?`.
 */
class PersistenceExpenseRepository(private val dsl: DSLContext) : ExpenseRepository {

    override fun create(expense: ExpenseEntity) {
        dsl.insertInto(EXPENSE)
            .set(expense.toRecord())
            .execute()
    }

    override fun sumAmount(personId: String): Long =
        dsl.select(coalesce(sum(EXPENSE.AMOUNT_CENTS), BigDecimal.ZERO))
            .from(EXPENSE)
            .where(EXPENSE.PERSON_ID.eq(personId))
            .fetchSingle()
            .value1()
            .toLong()

    override fun findByPerson(personId: String, after: ExpenseCursorValueObject?, limit: Int): List<ExpenseEntity> {
        var query = dsl.selectFrom(EXPENSE).where(EXPENSE.PERSON_ID.eq(personId))

        if (after != null) {
            query = query
                .and(row(EXPENSE.SPENT_ON, EXPENSE.ID)
                    .lessThan(row(after.spentOn, after.id)))
        }

        return query.orderBy(EXPENSE.SPENT_ON.desc(), EXPENSE.ID.desc())
            .limit(limit)
            .fetch { it.toEntity() }
    }

    override fun sumAmountInRange(personId: String, startDate: LocalDate, endDate: LocalDate): Long =
        dsl.select(coalesce(sum(EXPENSE.AMOUNT_CENTS), BigDecimal.ZERO))
            .from(EXPENSE)
            .where(EXPENSE.PERSON_ID.eq(personId))
            .and(EXPENSE.SPENT_ON.between(startDate, endDate))
            .fetchSingle()
            .value1()
            .toLong()
}
