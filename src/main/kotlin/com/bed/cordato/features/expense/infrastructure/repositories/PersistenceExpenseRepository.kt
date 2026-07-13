package com.bed.cordato.features.expense.infrastructure.repositories

import org.jooq.DSLContext

import com.bed.cordato.core.infrastructure.persistence.models.Tables.EXPENSE

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.infrastructure.repositories.mappers.toEntity
import com.bed.cordato.features.expense.infrastructure.repositories.mappers.toRecord
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Durable [ExpenseRepository] on PostgreSQL via jOOQ. Registering an expense is a plain INSERT: there is no
 * uniqueness constraint and no "already exists" state to reconcile, so — unlike identity's signup — there is
 * no datastore conflict to catch and fold into a value. A genuine datastore failure propagates as an
 * infrastructure exception; the record type never escapes this layer (the mapper does the translation).
 *
 * [findByPerson] is a filtered SELECT ordered in the database (`spent_on DESC, id DESC`) so the deterministic,
 * most-recent-first order is decided by PostgreSQL, not in memory; it reuses the `person_id` index from V3
 * (no new migration). An owner with no expenses yields an empty list, not `null`.
 */
class PersistenceExpenseRepository(private val dsl: DSLContext) : ExpenseRepository {

    override fun create(expense: ExpenseEntity) {
        dsl.insertInto(EXPENSE)
            .set(expense.toRecord())
            .execute()
    }

    override fun findByPerson(personId: String): List<ExpenseEntity> =
        dsl.selectFrom(EXPENSE)
            .where(EXPENSE.PERSON_ID.eq(personId))
            .orderBy(EXPENSE.SPENT_ON.desc(), EXPENSE.ID.desc())
            .fetch { it.toEntity() }
}
