package com.bed.cordato.features.budget.main

import org.jooq.DSLContext

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory

import com.bed.cordato.core.application.driven.ports.ClockPort
import com.bed.cordato.core.application.driven.ports.IdGeneratorPort

import com.bed.cordato.features.expense.application.driving.use_cases.SumAllExpensesUseCase
import com.bed.cordato.features.expense.application.driving.use_cases.SumExpensesInRangeUseCase

import com.bed.cordato.features.budget.infrastructure.adapters.ExpenseTotalSpentAdapter
import com.bed.cordato.features.budget.infrastructure.adapters.ExpenseSpentAmountAdapter
import com.bed.cordato.features.budget.infrastructure.repositories.PersistenceBudgetRepository

import com.bed.cordato.features.budget.application.driven.ports.ExpenseTotalSpentPort
import com.bed.cordato.features.budget.application.driven.ports.ExpenseSpentAmountPort

import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository

import com.bed.cordato.features.budget.application.driving.use_cases.CreateBudgetUseCase
import com.bed.cordato.features.budget.application.driving.use_cases.UpdateBudgetUseCase
import com.bed.cordato.features.budget.application.driving.use_cases.DeleteBudgetUseCase
import com.bed.cordato.features.budget.application.driving.use_cases.GetActiveBudgetUseCase
import com.bed.cordato.features.budget.application.driving.use_cases.GetDefaultBudgetUseCase
import com.bed.cordato.features.budget.application.driving.use_cases.DeleteAllOwnedBudgetsUseCase

/**
 * Budget's DI factory — binds budget's own ports to their adapters. The determinism ports (clock, id
 * generation) and the [DSLContext] come from [com.bed.cordato.core.main.CoreFactory]; this factory only
 * wires what budget owns and takes those kernel-provided collaborators as method parameters (no second
 * binding of either). Lives in budget's own `main` subpackage — the one place within the context where
 * wiring may reach across layers; domain and application never import Micronaut.
 *
 * [expenseSpentAmountPort]/[expenseTotalSpentPort] are the only places this factory reaches across a
 * context boundary: they wire the ACL adapters (ADR 0013) over expense's own [SumExpensesInRangeUseCase]/
 * [SumAllExpensesUseCase] beans, published by [com.bed.cordato.features.expense.main.ExpenseFactory] — the
 * sanctioned `budget → expense` dependency, never the reverse.
 */
@Factory
class BudgetFactory {

    @Singleton
    fun budgetRepository(dslContext: DSLContext): BudgetRepository = PersistenceBudgetRepository(dslContext)

    @Singleton
    fun createBudgetUseCase(generator: IdGeneratorPort, repository: BudgetRepository): CreateBudgetUseCase =
        CreateBudgetUseCase(generator, repository)

    @Singleton
    fun updateBudgetUseCase(repository: BudgetRepository): UpdateBudgetUseCase =
        UpdateBudgetUseCase(repository)

    @Singleton
    fun deleteBudgetUseCase(repository: BudgetRepository): DeleteBudgetUseCase =
        DeleteBudgetUseCase(repository)

    // Called by identity's PersonOwnedFinancialsAdapter (ADR 0013), never by a route in this context.
    @Singleton
    fun deleteAllOwnedBudgetsUseCase(repository: BudgetRepository): DeleteAllOwnedBudgetsUseCase =
        DeleteAllOwnedBudgetsUseCase(repository)

    @Singleton
    fun expenseSpentAmountPort(useCase: SumExpensesInRangeUseCase): ExpenseSpentAmountPort =
        ExpenseSpentAmountAdapter(useCase)

    @Singleton
    fun expenseTotalSpentPort(useCase: SumAllExpensesUseCase): ExpenseTotalSpentPort =
        ExpenseTotalSpentAdapter(useCase)

    @Singleton
    fun getActiveBudgetUseCase(
        clock: ClockPort,
        repository: BudgetRepository,
        expenseSpentAmountPort: ExpenseSpentAmountPort,
    ): GetActiveBudgetUseCase = GetActiveBudgetUseCase(clock, repository, expenseSpentAmountPort)

    @Singleton
    fun getDefaultBudgetUseCase(
        repository: BudgetRepository,
        expenseTotalSpentPort: ExpenseTotalSpentPort,
        expenseSpentAmountPort: ExpenseSpentAmountPort,
    ): GetDefaultBudgetUseCase = GetDefaultBudgetUseCase(repository, expenseTotalSpentPort, expenseSpentAmountPort)
}
