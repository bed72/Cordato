package com.bed.cordato.features.budget.factories

import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository
import com.bed.cordato.features.budget.application.driving.use_cases.DeleteBudgetUseCase

/**
 * Builds a [DeleteBudgetUseCase], mirroring `createBudgetUseCase` — the SUT builder lives in `factories/`,
 * never as a private helper inside the test class. The [repository] defaults to a fresh
 * [FakeBudgetRepository]; a test that seeds an existing budget passes its own instance.
 */
fun deleteBudgetUseCase(
    repository: BudgetRepository = FakeBudgetRepository(),
): DeleteBudgetUseCase = DeleteBudgetUseCase(repository)
