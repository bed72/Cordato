package com.bed.cordato.features.expense.factories

import java.time.LocalDate

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.domain.value_objects.ExpenseCursorValueObject
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Deterministic [ExpenseRepository] fake for pure use-case tests: [create] records the persisted expense so a
 * test can assert what was written (and how many). Mirrors identity's `FakePersonRepository` — a stateful
 * collaborator lives in the owning package's `factories/`, never inline in a test class.
 *
 * [findByPerson] returns the [created] expenses whose owner is [personId], in **insertion order**, applying
 * only the keyset cutoff (`(spentOn, id)` strictly less than [after], in insertion order — this fake does
 * **not** sort) and the [limit] — the fake hands back exactly what it was given, so a use-case test asserts
 * the owner-slicing and the paging cutoff/limit, not the ordering (the deterministic order is the real
 * adapter's guarantee, covered by its own test). A test that needs a specific order seeds rows in that order.
 *
 * [sumAmountInRange] sums the [created] expenses owned by [personId] whose date falls within
 * `[startDate, endDate]` (both included) — an in-memory replay of the real adapter's `SUM`/`COALESCE`
 * query, `0` when nothing matches.
 *
 * [sumAmount] sums **all** [created] expenses owned by [personId], with no date filter — same replay
 * posture, `0` when the person has none.
 */
class FakeExpenseRepository : ExpenseRepository {
    val created = mutableListOf<ExpenseEntity>()

    override fun create(expense: ExpenseEntity) {
        created.add(expense)
    }

    override fun findByPerson(personId: String, after: ExpenseCursorValueObject?, limit: Int): List<ExpenseEntity> =
        created
            .filter { it.personId == personId }
            .filter { after == null || isAfter(it, after) }
            .take(limit)

    override fun sumAmountInRange(personId: String, startDate: LocalDate, endDate: LocalDate): Long =
        created
            .filter { it.personId == personId }
            .filter { it.date.value in startDate..endDate }
            .sumOf { it.amount.cents }

    override fun sumAmount(personId: String): Long =
        created
            .filter { it.personId == personId }
            .sumOf { it.amount.cents }

    private fun isAfter(expense: ExpenseEntity, cursor: ExpenseCursorValueObject): Boolean =
        expense.date.value < cursor.spentOn || (expense.date.value == cursor.spentOn && expense.id < cursor.id)
}
