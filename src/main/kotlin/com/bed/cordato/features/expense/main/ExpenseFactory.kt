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
import com.bed.cordato.features.expense.application.driving.use_cases.SumAllExpensesUseCase
import com.bed.cordato.features.expense.application.driving.use_cases.SumExpensesInRangeUseCase

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

    @Singleton
    fun sumAllExpensesUseCase(repository: ExpenseRepository): SumAllExpensesUseCase =
        SumAllExpensesUseCase(repository)

    @Singleton
    fun sumExpensesInRangeUseCase(repository: ExpenseRepository): SumExpensesInRangeUseCase =
        SumExpensesInRangeUseCase(repository)

    @Singleton
    fun listExpensesUseCase(repository: ExpenseRepository): ListExpensesUseCase = ListExpensesUseCase(repository)

    @Singleton
    fun expenseRepository(
        cache: CachePort,
        dslContext: DSLContext,
        @Value($$"${expense.cache.list-ttl-seconds:60}") ttlSeconds: Long,
    ): ExpenseRepository = CachingExpenseRepository(
        adapter = GenerationalCacheAdapter(prefix = "expenses", ttl = Duration.ofSeconds(ttlSeconds), cache = cache),
        repository = PersistenceExpenseRepository(dslContext),
    )

    @Singleton
    fun createExpenseUseCase(
        clock: ClockPort,
        generator: IdGeneratorPort,
        repository: ExpenseRepository,
    ): CreateExpenseUseCase = CreateExpenseUseCase(clock, generator, repository)
}
