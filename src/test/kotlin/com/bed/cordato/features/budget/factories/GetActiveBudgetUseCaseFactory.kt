package com.bed.cordato.features.budget.factories

import java.time.Instant

import com.bed.cordato.core.factories.clockFixedAt

import com.bed.cordato.core.application.driven.ports.ClockPort

import com.bed.cordato.features.budget.application.driven.ports.ExpenseSpentAmountPort
import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository
import com.bed.cordato.features.budget.application.driving.commands.GetActiveBudgetCommand
import com.bed.cordato.features.budget.application.driving.use_cases.GetActiveBudgetUseCase

/**
 * Builds a [GetActiveBudgetUseCase] over deterministic collaborators, mirroring [createBudgetUseCase] — the
 * SUT builder lives in `factories/`, never as a private helper inside the test class. [clock] defaults to a
 * fixed "today" of 2026-07-15; [repository] to a fresh [FakeBudgetRepository]; [expenseSpentAmountPort] to
 * one that always answers `0`.
 */
fun getActiveBudgetUseCase(
    repository: BudgetRepository = FakeBudgetRepository(),
    clock: ClockPort = clockFixedAt(Instant.parse("2026-07-15T12:00:00Z")),
    expenseSpentAmountPort: ExpenseSpentAmountPort = expenseSpentAmountPortOf(0),
): GetActiveBudgetUseCase = GetActiveBudgetUseCase(clock, repository, expenseSpentAmountPort)

/** Convenience default so most tests only ever state the [personId] they care about. */
fun getActiveBudgetCommand(personId: String = "person-1"): GetActiveBudgetCommand = GetActiveBudgetCommand(personId)
