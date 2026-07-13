package com.bed.cordato.features.expense.factories

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Deterministic [ExpenseRepository] fake for pure use-case tests: [create] records the persisted expense so a
 * test can assert what was written (and how many). Mirrors identity's `FakePersonRepository` — a stateful
 * collaborator lives in the owning package's `factories/`, never inline in a test class.
 *
 * [findByPerson] slices [created] by owner, in insertion order — the fake does no sorting. The deterministic
 * `spent_on`/`id` order is the real jOOQ repository's job (covered by its own Postgres test); a use-case test
 * asserts only the owner slicing and the pass-through, not the ordering.
 */
class FakeExpenseRepository : ExpenseRepository {
    val created = mutableListOf<ExpenseEntity>()

    override fun create(expense: ExpenseEntity) {
        created.add(expense)
    }

    override fun findByPerson(personId: String): List<ExpenseEntity> = created.filter { it.personId == personId }
}
