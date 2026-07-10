package com.bed.cordato.features.expense.factories

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Deterministic [ExpenseRepository] fake for pure use-case tests: [create] records the persisted expense so a
 * test can assert what was written (and how many). Mirrors identity's `FakePersonRepository` — a stateful
 * collaborator lives in the owning package's `factories/`, never inline in a test class.
 */
class FakeExpenseRepository : ExpenseRepository {
    val created = mutableListOf<ExpenseEntity>()

    override fun create(expense: ExpenseEntity) {
        created.add(expense)
    }
}
