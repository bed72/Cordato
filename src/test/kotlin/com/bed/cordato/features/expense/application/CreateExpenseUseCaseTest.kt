package com.bed.cordato.features.expense.application

import kotlin.test.Test
import kotlin.test.assertIs
import kotlin.test.assertTrue
import kotlin.test.assertNull
import kotlin.test.assertEquals

import com.bed.cordato.features.expense.factories.EXPENSE_TODAY
import com.bed.cordato.features.expense.factories.createExpenseUseCase
import com.bed.cordato.features.expense.factories.createExpenseCommand
import com.bed.cordato.features.expense.factories.FakeExpenseRepository

import com.bed.cordato.features.expense.domain.errors.CreateExpenseError
import com.bed.cordato.features.expense.domain.value_objects.DescriptionValueObject

import com.bed.cordato.features.expense.application.driving.results.CreateExpenseResult

class CreateExpenseUseCaseTest {

    @Test
    fun `a valid command creates and persists the expense`() {
        val repository = FakeExpenseRepository()

        val data = createExpenseUseCase(id = "expense-42", repository = repository)(createExpenseCommand())

        val expense = assertIs<CreateExpenseResult.Success>(data).expense
        assertEquals("expense-42", expense.id)
        assertEquals("person-1", expense.personId)
        assertEquals(1_500, expense.amount.cents)
        assertEquals(EXPENSE_TODAY, expense.date.value)
        assertEquals("Café", expense.description!!.value)
        assertEquals(listOf(expense), repository.created)
    }

    @Test
    fun `a non-positive amount is rejected and persists nothing`() {
        val repository = FakeExpenseRepository()

        val data = createExpenseUseCase(repository = repository)(createExpenseCommand(amountInCents = 0))

        assertEquals(CreateExpenseError.InvalidAmount, assertIs<CreateExpenseResult.Failure>(data).error)
        assertTrue(repository.created.isEmpty())
    }

    @Test
    fun `a future date is rejected and persists nothing`() {
        val repository = FakeExpenseRepository()

        val data = createExpenseUseCase(repository = repository)(createExpenseCommand(date = EXPENSE_TODAY.plusDays(1)))

        assertEquals(CreateExpenseError.FutureDate, assertIs<CreateExpenseResult.Failure>(data).error)
        assertTrue(repository.created.isEmpty())
    }

    @Test
    fun `a past date is kept exactly`() {
        val past = EXPENSE_TODAY.minusDays(3)

        val data = createExpenseUseCase()(createExpenseCommand(date = past))

        assertEquals(past, assertIs<CreateExpenseResult.Success>(data).expense.date.value)
    }

    @Test
    fun `an absent date defaults to today`() {
        val data = createExpenseUseCase()(createExpenseCommand(date = null))

        assertEquals(EXPENSE_TODAY, assertIs<CreateExpenseResult.Success>(data).expense.date.value)
    }

    @Test
    fun `an over-length description is rejected and persists nothing`() {
        val repository = FakeExpenseRepository()
        val tooLong = "a".repeat(DescriptionValueObject.MAX_LENGTH + 1)

        val data = createExpenseUseCase(repository = repository)(createExpenseCommand(description = tooLong))

        assertEquals(CreateExpenseError.InvalidDescription, assertIs<CreateExpenseResult.Failure>(data).error)
        assertTrue(repository.created.isEmpty())
    }

    @Test
    fun `a blank description becomes an absent one`() {
        val data = createExpenseUseCase()(createExpenseCommand(description = "   "))

        assertNull(assertIs<CreateExpenseResult.Success>(data).expense.description)
    }

    @Test
    fun `a null description becomes an absent one`() {
        val data = createExpenseUseCase()(createExpenseCommand(description = null))

        assertNull(assertIs<CreateExpenseResult.Success>(data).expense.description)
    }

    @Test
    fun `the owner is the command's person, never a body-supplied id`() {
        val data = createExpenseUseCase()(createExpenseCommand(personId = "actor-owner"))

        assertEquals("actor-owner", assertIs<CreateExpenseResult.Success>(data).expense.personId)
    }
}
