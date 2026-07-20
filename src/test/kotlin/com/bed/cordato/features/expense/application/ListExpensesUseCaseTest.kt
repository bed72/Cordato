package com.bed.cordato.features.expense.application

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

import com.bed.cordato.features.expense.factories.expense
import com.bed.cordato.features.expense.factories.listExpensesCommand
import com.bed.cordato.features.expense.factories.listExpensesUseCase
import com.bed.cordato.features.expense.factories.FakeExpenseRepository

import com.bed.cordato.features.expense.domain.value_objects.ExpenseCursorValueObject

class ListExpensesUseCaseTest {

    @Test
    fun `returns only the expenses owned by the command's person`() {
        val repository = FakeExpenseRepository()
        val mine = expense(id = "mine-1", personId = "person-1")
        val also = expense(id = "mine-2", personId = "person-1")
        repository.create(mine)
        repository.create(expense(id = "theirs", personId = "person-2"))
        repository.create(also)

        val page = listExpensesUseCase(repository)(listExpensesCommand(personId = "person-1"))

        assertEquals(listOf(mine, also), page.items)
    }

    @Test
    fun `a person with no expenses gets an empty page, never an error`() {
        val repository = FakeExpenseRepository()
        repository.create(expense(id = "theirs", personId = "person-2"))

        val page = listExpensesUseCase(repository)(listExpensesCommand(personId = "person-1"))

        assertTrue(page.items.isEmpty())
        assertNull(page.nextCursor)
    }

    @Test
    fun `a page with more items than the limit is cut down and offers a next cursor`() {
        val repository = FakeExpenseRepository()
        listOf("a", "b", "c").forEach { id -> repository.create(expense(id = id, personId = "person-1")) }

        val page = listExpensesUseCase(repository)(listExpensesCommand(personId = "person-1", limit = 2))

        assertEquals(2, page.items.size)
        assertNotNull(page.nextCursor)
    }

    @Test
    fun `the last page offers no next cursor`() {
        val repository = FakeExpenseRepository()
        listOf("a", "b").forEach { id -> repository.create(expense(id = id, personId = "person-1")) }

        val page = listExpensesUseCase(repository)(listExpensesCommand(personId = "person-1", limit = 20))

        assertEquals(2, page.items.size)
        assertNull(page.nextCursor)
    }

    @Test
    fun `the next cursor is derived from the last kept item, not the probe row`() {
        val kept = expense(id = "b", personId = "person-1", date = LocalDate.of(2026, 7, 5))
        val probe = expense(id = "a", personId = "person-1", date = LocalDate.of(2026, 7, 1))
        val repository = FakeExpenseRepository()
        repository.create(kept)
        repository.create(probe)

        val page = listExpensesUseCase(repository)(listExpensesCommand(personId = "person-1", limit = 1))

        assertEquals(listOf(kept), page.items)
        assertEquals(ExpenseCursorValueObject.of(kept.date.value, kept.id), page.nextCursor)
    }

    @Test
    fun `the limit-plus-one probe row never leaks into the returned items`() {
        val repository = FakeExpenseRepository()
        listOf("a", "b", "c").forEach { id -> repository.create(expense(id = id, personId = "person-1")) }

        val page = listExpensesUseCase(repository)(listExpensesCommand(personId = "person-1", limit = 3))

        // Exactly 3 come back even though the repository was asked for 4 (limit + 1) under the hood.
        assertNull(page.nextCursor)
        assertEquals(3, page.items.size)
    }
}
