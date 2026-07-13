package com.bed.cordato.features.expense.factories

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Deterministic [ExpenseRepository] fake for pure use-case tests: [create] records the persisted expense so a
 * test can assert what was written (and how many). Mirrors identity's `FakePersonRepository` — a stateful
 * collaborator lives in the owning package's `factories/`, never inline in a test class.
 *
 * [findByPerson] returns the [created] expenses whose owner is [personId], in insertion order — the fake
 * hands back exactly what it was given, so a use-case test asserts the owner-slicing and the pass-through,
 * not the ordering (the deterministic order is the real adapter's guarantee, covered by its own test). A
 * test that seeds specific rows just [create]s them first.
 */
class FakeExpenseRepository : ExpenseRepository {
    val created = mutableListOf<ExpenseEntity>()

    override fun create(expense: ExpenseEntity) {
        created.add(expense)
    }

    override fun findByPerson(personId: String): List<ExpenseEntity> =
        created.filter { it.personId == personId }
}
