package com.bed.cordato.features.budget.factories

import java.time.LocalDate

import com.bed.cordato.features.budget.domain.entities.BudgetEntity
import com.bed.cordato.features.budget.domain.enums.BudgetStatusEnum
import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository

/**
 * Deterministic [BudgetRepository] fake for pure use-case tests: [create] records the persisted budget so a
 * test can assert what was written (and how many). Mirrors expense's `FakeExpenseRepository` — a stateful
 * collaborator lives in the owning package's `factories/`, never inline in a test class.
 *
 * [hasOverlappingLiveBudget] replays the same inclusive-boundary intersection rule the real adapter's query
 * enforces, scoped to [personId] and only against [BudgetStatusEnum.LIVE] budgets already [created].
 */
class FakeBudgetRepository : BudgetRepository {
    val created = mutableListOf<BudgetEntity>()

    override fun hasOverlappingLiveBudget(personId: String, startDate: LocalDate, endDate: LocalDate): Boolean =
        created.any { budget ->
            budget.personId == personId &&
                budget.status == BudgetStatusEnum.LIVE &&
                startDate <= budget.period.endDate &&
                budget.period.startDate <= endDate
        }

    override fun create(budget: BudgetEntity) {
        created.add(budget)
    }
}
