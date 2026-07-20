package com.bed.cordato.features.expense.main

import java.time.Duration

import org.jooq.DSLContext

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Value
import io.micronaut.context.annotation.Factory

import com.bed.cordato.core.application.driven.ports.ClockPort
import com.bed.cordato.core.application.driven.ports.CachePort
import com.bed.cordato.core.application.driven.ports.IdGeneratorPort
import com.bed.cordato.core.infrastructure.adapters.cache.GenerationalCacheAdapter

import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository
import com.bed.cordato.features.expense.application.driving.use_cases.ListExpensesUseCase
import com.bed.cordato.features.expense.application.driving.use_cases.CreateExpenseUseCase

import com.bed.cordato.features.expense.infrastructure.repositories.CachingExpenseRepository
import com.bed.cordato.features.expense.infrastructure.repositories.PersistenceExpenseRepository

/**
 * Expense's DI factory — binds expense's own ports to their adapters. The determinism ports (clock, id
 * generation), the [CachePort] and the [DSLContext] come from [com.bed.cordato.core.main.CoreFactory]; this
 * factory only wires what expense owns and takes those kernel-provided collaborators as method parameters
 * (no second binding of any of them). Lives in expense's own `main` subpackage — the one place within the
 * context where wiring may reach across layers; domain and application never import Micronaut.
 */
@Factory
class ExpenseFactory {

    // The durable PostgreSQL adapter wrapped by the cache-valkey read-through/invalidation decorator, so
    // both use cases below see only the ExpenseRepository port, cache-agnostic. The DSLContext and CachePort
    // come from CoreFactory; the TTL is expense's own config, a floor behind the decorator's primary
    // generation-based invalidation. The GenerationalCacheAdapter is built here (not inside
    // CachingExpenseRepository) and handed in already scoped to the "expenses" prefix, so the decorator only
    // ever receives its finished collaborator. Pure use-case tests use a hand-written fake
    // (factories.FakeExpenseRepository), not a production binding.
    @Singleton
    fun expenseRepository(
        cache: CachePort,
        dslContext: DSLContext,
        @Value($$"${expense.cache.list-ttl-seconds:60}") ttlSeconds: Long,
    ): ExpenseRepository = CachingExpenseRepository(
        adapter = GenerationalCacheAdapter(prefix = "expenses", ttl = Duration.ofSeconds(ttlSeconds), cache = cache),
        repository = PersistenceExpenseRepository(dslContext),
    )

    // Clock and id generator come from CoreFactory; the expense repository is expense's own binding above.
    @Singleton
    fun createExpenseUseCase(
        clock: ClockPort,
        generator: IdGeneratorPort,
        repository: ExpenseRepository,
    ): CreateExpenseUseCase = CreateExpenseUseCase(clock, generator, repository)

    // Reads the actor's own expenses; inherits the same (cache-decorated) repository binding above.
    @Singleton
    fun listExpensesUseCase(repository: ExpenseRepository): ListExpensesUseCase = ListExpensesUseCase(repository)
}
