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
    fun `returns only the command owner's expenses, never another person's`() {
        val repository = FakeExpenseRepository()
        val mine = expense(id = "expense-1", personId = "person-1")
        repository.create(mine)
        repository.create(expense(id = "expense-2", personId = "person-2"))

        val data = listExpensesUseCase(repository)(ListExpensesCommand("person-1"))

        assertEquals(listOf(mine), data)
    }

    @Test
    fun `an owner with no expenses gets an empty list, not an error`() {
        val repository = FakeExpenseRepository()
        repository.create(expense(id = "expense-1", personId = "someone-else"))

        val data = listExpensesUseCase(repository)(ListExpensesCommand("person-1"))

        assertTrue(data.isEmpty())
    }

    @Test
    fun `the result passes the repository's list through unchanged`() {
        val repository = FakeExpenseRepository()
        val first = expense(id = "expense-1", personId = "person-1")
        val second = expense(id = "expense-2", personId = "person-1")
        repository.create(first)
        repository.create(second)

        val data = listExpensesUseCase(repository)(ListExpensesCommand("person-1"))

        // The use case adds no logic over the repository — the order it returns is whatever the repository gave.
        assertEquals(listOf(first, second), data)
    }
}
