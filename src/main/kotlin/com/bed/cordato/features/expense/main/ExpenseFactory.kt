package com.bed.cordato.features.expense.main

import org.jooq.DSLContext

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory

import com.bed.cordato.core.application.driven.ports.ClockPort
import com.bed.cordato.core.application.driven.ports.IdGeneratorPort

import com.bed.cordato.features.expense.application.driving.use_cases.CreateExpenseUseCase
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

import com.bed.cordato.features.expense.infrastructure.repositories.PersistenceExpenseRepository

/**
 * Expense's DI factory — binds expense's own ports to their adapters. The determinism ports (clock, id
 * generation) and the [DSLContext] come from [com.bed.cordato.core.main.CoreFactory]; this factory only wires
 * what expense owns and takes those kernel-provided collaborators as method parameters (no second
 * [DSLContext] binding). Lives in expense's own `main` subpackage — the one place within the context where
 * wiring may reach across layers; domain and application never import Micronaut.
 */
@Factory
class ExpenseFactory {

    // Durable PostgreSQL adapter; the DSLContext comes from CoreFactory. Pure use-case tests use a
    // hand-written fake (factories.FakeExpenseRepository), not a production binding.
    @Singleton
    fun expenseRepository(dslContext: DSLContext): ExpenseRepository = PersistenceExpenseRepository(dslContext)

    // Clock and id generator come from CoreFactory; the expense repository is expense's own binding above.
    @Singleton
    fun createExpenseUseCase(
        clock: ClockPort,
        generator: IdGeneratorPort,
        repository: ExpenseRepository,
    ): CreateExpenseUseCase = CreateExpenseUseCase(clock, generator, repository)
}
