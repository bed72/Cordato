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
 */
class PersistenceExpenseRepository(private val dsl: DSLContext) : ExpenseRepository {

    override fun create(expense: ExpenseEntity) {
        dsl.insertInto(EXPENSE)
            .set(expense.toRecord())
            .execute()
    }

    // Every expense of one owner, ordered in the datastore (never in memory): most recent day first, with a
    // stable `id` tie-break so same-day expenses keep a deterministic order. Reuses the V3 `person_id` index;
    // the record type is mapped back to the domain here (`toEntity`) so it never escapes infrastructure.
    override fun findByPerson(personId: String): List<ExpenseEntity> =
        dsl.selectFrom(EXPENSE)
            .where(EXPENSE.PERSON_ID.eq(personId))
            .orderBy(EXPENSE.SPENT_ON.desc(), EXPENSE.ID.desc())
            .fetch { it.toEntity() }
}
