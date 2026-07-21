package com.bed.cordato.features.budget.factories

import com.bed.cordato.core.factories.idGeneratorOf

import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository
import com.bed.cordato.features.budget.application.driving.use_cases.CreateBudgetUseCase

/**
 * Builds a [CreateBudgetUseCase] over a deterministic id generator, mirroring expense's
 * `createExpenseUseCase` — the SUT builder lives in `factories/`, never as a private helper inside the test
 * class. The [repository] defaults to a fresh [FakeBudgetRepository]; a test that asserts what was
 * persisted (or seeds an overlap) passes its own instance.
 */
fun createBudgetUseCase(
    id: String = "budget-1",
    repository: BudgetRepository = FakeBudgetRepository(),
): CreateBudgetUseCase = CreateBudgetUseCase(idGeneratorOf(id), repository)
