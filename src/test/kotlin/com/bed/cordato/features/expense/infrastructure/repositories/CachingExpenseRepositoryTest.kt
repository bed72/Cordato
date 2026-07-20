package com.bed.cordato.features.expense.infrastructure.repositories

import java.time.Duration

import kotlin.test.Test
import kotlin.test.assertEquals

import com.bed.cordato.core.factories.FakeCachePort
import com.bed.cordato.core.factories.generationalCacheAdapter

import com.bed.cordato.features.expense.factories.expense
import com.bed.cordato.features.expense.factories.FakeExpenseRepository

private val TTL = Duration.ofSeconds(60)

/**
 * Unit cover of [CachingExpenseRepository]'s own policy in isolation — a [FakeExpenseRepository] stands in
 * for the datastore, so these tests exercise only the read-through/invalidation/degrade logic, not real
 * persistence (see `PersistenceExpenseRepositoryTest`) or a real Valkey (see `ValkeyCacheAdapterTest`).
 */
class CachingExpenseRepositoryTest {

    @Test
    fun `a read-through hit is served from the cache, not re-asked from the datastore`() {
        val persistence = FakeExpenseRepository()
        persistence.create(expense(id = "e-1", personId = "person-1"))
        val adapter = generationalCacheAdapter(prefix = "expenses", ttl = TTL, cache = FakeCachePort())
        val repository = CachingExpenseRepository(adapter = adapter, repository = persistence)

        val first = repository.findByPerson("person-1", after = null, limit = 20)
        // Removing the row underneath the decorator means a second call that still sees it must have come
        // from the cache, not the datastore.
        persistence.created.clear()
        val second = repository.findByPerson("person-1", after = null, limit = 20)

        assertEquals(first, second)
        assertEquals(listOf("e-1"), second.map { it.id })
    }

    @Test
    fun `registering an expense invalidates the cached listing of its owner`() {
        val persistence = FakeExpenseRepository()
        val adapter = generationalCacheAdapter(prefix = "expenses", ttl = TTL, cache = FakeCachePort())
        val repository = CachingExpenseRepository(adapter = adapter, repository = persistence)
        repository.findByPerson("person-1", after = null, limit = 20) // caches the (empty) page

        repository.create(expense(id = "e-1", personId = "person-1"))
        val listed = repository.findByPerson("person-1", after = null, limit = 20)

        assertEquals(listOf("e-1"), listed.map { it.id })
    }

    @Test
    fun `invalidating one person's listing never affects another's cached page`() {
        val persistence = FakeExpenseRepository()
        val adapter = generationalCacheAdapter(prefix = "expenses", ttl = TTL, cache = FakeCachePort())
        val repository = CachingExpenseRepository(adapter = adapter, repository = persistence)
        repository.create(expense(id = "b-1", personId = "person-2"))
        repository.findByPerson("person-2", after = null, limit = 20) // caches person-2's page

        repository.create(expense(id = "a-1", personId = "person-1")) // invalidates only person-1's generation
        persistence.create(expense(id = "b-2", personId = "person-2")) // bypasses the decorator — no invalidation

        // person-2's cached page is untouched by person-1's invalidation, so this read is still served from
        // cache and does not see the out-of-band b-2 row.
        val stillCached = repository.findByPerson("person-2", after = null, limit = 20)

        assertEquals(listOf("b-1"), stillCached.map { it.id })
    }

    @Test
    fun `a cache read failure degrades to the datastore instead of failing the listing`() {
        val persistence = FakeExpenseRepository()
        persistence.create(expense(id = "e-1", personId = "person-1"))
        val cache = FakeCachePort().apply { available = false }
        val adapter = generationalCacheAdapter(prefix = "expenses", ttl = TTL, cache = cache)
        val repository = CachingExpenseRepository(adapter = adapter, repository = persistence)

        val listed = repository.findByPerson("person-1", after = null, limit = 20)

        assertEquals(listOf("e-1"), listed.map { it.id })
    }

    @Test
    fun `a cache write failure never fails the write itself`() {
        val persistence = FakeExpenseRepository()
        val cache = FakeCachePort().apply { available = false }
        val adapter = generationalCacheAdapter(prefix = "expenses", ttl = TTL, cache = cache)
        val repository = CachingExpenseRepository(adapter = adapter, repository = persistence)

        repository.create(expense(id = "e-1", personId = "person-1"))

        assertEquals(listOf("e-1"), persistence.created.map { it.id })
    }
}
