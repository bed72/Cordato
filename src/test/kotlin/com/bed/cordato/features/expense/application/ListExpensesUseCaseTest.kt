package com.bed.cordato.features.expense.application

import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.assertEquals

import com.bed.cordato.features.expense.factories.expense
import com.bed.cordato.features.expense.factories.listExpensesUseCase
import com.bed.cordato.features.expense.factories.FakeExpenseRepository

import com.bed.cordato.features.expense.application.driving.commands.ListExpensesCommand

class ListExpensesUseCaseTest {

    @Test
    fun `returns only the expenses owned by the command's person`() {
        val repository = FakeExpenseRepository()
        val mine = expense(id = "mine-1", personId = "person-1")
        val also = expense(id = "mine-2", personId = "person-1")
        repository.create(mine)
        repository.create(expense(id = "theirs", personId = "person-2"))
        repository.create(also)

        val listed = listExpensesUseCase(repository)(ListExpensesCommand("person-1"))

        assertEquals(listOf(mine, also), listed)
    }

    @Test
    fun `a person with no expenses gets an empty list, never an error`() {
        val repository = FakeExpenseRepository()
        repository.create(expense(id = "theirs", personId = "person-2"))

        val listed = listExpensesUseCase(repository)(ListExpensesCommand("person-1"))

        assertTrue(listed.isEmpty())
    }

    @Test
    fun `the use case is a pass-through of what the repository returns`() {
        val repository = FakeExpenseRepository()
        val first = expense(id = "e-1", personId = "person-1")
        val second = expense(id = "e-2", personId = "person-1")
        repository.create(first)
        repository.create(second)

        val listed = listExpensesUseCase(repository)(ListExpensesCommand("person-1"))

        // The order is the repository's guarantee; the use case relays it verbatim.
        assertEquals(repository.findByPerson("person-1"), listed)
    }
}
