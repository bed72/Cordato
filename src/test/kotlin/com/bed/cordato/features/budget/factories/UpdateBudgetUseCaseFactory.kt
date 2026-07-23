package com.bed.cordato.features.budget.factories

import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository
import com.bed.cordato.features.budget.application.driving.use_cases.UpdateBudgetUseCase

/**
 * Builds an [UpdateBudgetUseCase], mirroring `createBudgetUseCase` — the SUT builder lives in `factories/`,
 * never as a private helper inside the test class. The [repository] defaults to a fresh
 * [FakeBudgetRepository]; a test that seeds an existing budget (or an overlap) passes its own instance.
 */
fun updateBudgetUseCase(
    repository: BudgetRepository = FakeBudgetRepository(),
): UpdateBudgetUseCase = UpdateBudgetUseCase(repository)
