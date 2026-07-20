package com.bed.cordato.features.expense.infrastructure.repositories

import com.bed.cordato.core.infrastructure.adapters.cache.GenerationalCacheAdapter

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.domain.value_objects.ExpenseCursorValueObject
import com.bed.cordato.features.expense.infrastructure.repositories.mappers.toCacheJson
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository
import com.bed.cordato.features.expense.infrastructure.repositories.mappers.toExpenseEntities

/**
 * A read-through cache decorator over [repository], serving [findByPerson] from Valkey (via [adapter]) when
 * possible so `application`/`domain` never know a cache exists — they see only the [ExpenseRepository] port.
 * This is the **seam** the cache-valkey capability hangs off: the only place expense's cache policy lives.
 *
 * The generation-based read-through/write-through/invalidation mechanics (key shape, TTL, failure-as-miss
 * posture) are core's shared [GenerationalCacheAdapter]; [adapter] arrives pre-scoped to the `"expenses"`
 * prefix from [com.bed.cordato.features.expense.main.ExpenseFactory], not built here, so this class only
 * owns what's expense-specific: the cursor/limit token that becomes the cache key's [suffix], and the JSON
 * (de)serialization of [ExpenseEntity] lists.
 */
class CachingExpenseRepository(
    private val repository: ExpenseRepository,
    private val adapter: GenerationalCacheAdapter,
) : ExpenseRepository {

    override fun create(expense: ExpenseEntity) {
        repository.create(expense)
        adapter.invalidate(expense.personId)
    }

    override fun findByPerson(personId: String, after: ExpenseCursorValueObject?, limit: Int): List<ExpenseEntity> {
        val suffix = suffix(after, limit)

        adapter.readThrough(personId, suffix) { it.toExpenseEntities() }?.let { return it }

        val fetched = repository.findByPerson(personId, after, limit)
        adapter.writeThrough(personId, suffix, fetched) { it.toCacheJson() }

        return fetched
    }

    private fun suffix(after: ExpenseCursorValueObject?, limit: Int): String {
        val token = after?.let { "${it.spentOn}|${it.id}" } ?: "first"

        return "$token:$limit"
    }
}
