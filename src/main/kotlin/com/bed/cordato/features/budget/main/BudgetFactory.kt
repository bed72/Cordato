package com.bed.cordato.features.budget.main

import org.jooq.DSLContext

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory

import com.bed.cordato.core.application.driven.ports.IdGeneratorPort

import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository
import com.bed.cordato.features.budget.application.driving.use_cases.CreateBudgetUseCase

import com.bed.cordato.features.budget.infrastructure.repositories.PersistenceBudgetRepository

/**
 * Budget's DI factory — binds budget's own ports to their adapters. The determinism port (id generation)
 * and the [DSLContext] come from [com.bed.cordato.core.main.CoreFactory]; this factory only wires what
 * budget owns and takes those kernel-provided collaborators as method parameters (no second binding of
 * either). Lives in budget's own `main` subpackage — the one place within the context where wiring may
 * reach across layers; domain and application never import Micronaut.
 */
@Factory
class BudgetFactory {

    @Singleton
    fun budgetRepository(dslContext: DSLContext): BudgetRepository = PersistenceBudgetRepository(dslContext)

    @Singleton
    fun createBudgetUseCase(generator: IdGeneratorPort, repository: BudgetRepository): CreateBudgetUseCase =
        CreateBudgetUseCase(generator, repository)
}
