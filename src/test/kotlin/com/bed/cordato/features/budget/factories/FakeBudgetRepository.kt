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
 * [update] replaces the [created] entry with the same `id`, mirroring the real adapter's plain
 * locate-by-id write. [delete] replays the real adapter's own owner+vivacity check in the same "write":
 * it flips the entry to [BudgetStatusEnum.DELETED] only when it exists, belongs to [personId], and is
 * currently live, returning whether it changed anything.
 *
 * [findById] returns the [created] entry with the given `id`, of any owner or status, `null` when none
 * matches — no owner/status filter, mirroring the real adapter's port contract.
 *
 * [hasOverlappingLiveBudget] replays the same inclusive-boundary intersection rule the real adapter's query
 * enforces, scoped to [personId] and only against [BudgetStatusEnum.LIVE] budgets already [created];
 * [excludeId], when given, is never counted as an overlap candidate.
 *
 * [findLiveBudgetCovering] replays the same inclusive-boundary coverage rule, scoped to [personId] and only
 * against [BudgetStatusEnum.LIVE] budgets already [created]; `null` when none covers [date].
 *
 * [findAllLiveBudgets] returns every [BudgetStatusEnum.LIVE] budget already [created] owned by [personId],
 * an empty list when there is none.
 */
class FakeBudgetRepository : BudgetRepository {
    val created = mutableListOf<BudgetEntity>()

    override fun findById(id: String): BudgetEntity? = created.find { it.id == id }

    override fun create(budget: BudgetEntity) {
        created.add(budget)
    }

    override fun update(budget: BudgetEntity) {
        val index = created.indexOfFirst { it.id == budget.id }
        if (index >= 0) created[index] = budget
    }

    override fun delete(id: String, personId: String): Boolean {
        val index = created.indexOfFirst { it.id == id && it.personId == personId && it.status == BudgetStatusEnum.LIVE }
        if (index < 0) return false

        created[index] = created[index].copy(status = BudgetStatusEnum.DELETED)
        return true
    }

    override fun findAllLiveBudgets(personId: String): List<BudgetEntity> =
        created.filter { it.personId == personId && it.status == BudgetStatusEnum.LIVE }

    override fun hasOverlappingLiveBudget(
        personId: String,
        startDate: LocalDate,
        endDate: LocalDate,
        excludeId: String?,
    ): Boolean =
        created.any { budget ->
            budget.id != excludeId &&
                budget.personId == personId &&
                budget.status == BudgetStatusEnum.LIVE &&
                startDate <= budget.period.endDate &&
                budget.period.startDate <= endDate
        }

    override fun findLiveBudgetCovering(personId: String, date: LocalDate): BudgetEntity? =
        created.find { budget ->
            budget.personId == personId &&
                budget.status == BudgetStatusEnum.LIVE &&
                budget.period.startDate <= date &&
                budget.period.endDate >= date
        }
}
