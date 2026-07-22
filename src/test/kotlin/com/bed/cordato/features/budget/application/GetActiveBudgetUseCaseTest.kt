package com.bed.cordato.features.budget.application

import io.mockk.verify

import java.time.Instant
import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

import com.bed.cordato.core.factories.clockFixedAt

import com.bed.cordato.features.budget.factories.budget
import com.bed.cordato.features.budget.factories.FakeBudgetRepository
import com.bed.cordato.features.budget.factories.getActiveBudgetCommand
import com.bed.cordato.features.budget.factories.getActiveBudgetUseCase
import com.bed.cordato.features.budget.factories.expenseSpentAmountPortOf

private val TODAY = clockFixedAt(Instant.parse("2026-07-15T12:00:00Z"))

internal class GetActiveBudgetUseCaseTest {

    @Test
    fun `returns the live budget covering today, enriched with spent and remaining`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(id = "budget-1", personId = "person-1", amountInCents = 100_000, startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 31)))
        }
        val port = expenseSpentAmountPortOf(45_000)

        val data = getActiveBudgetUseCase(clock = TODAY, repository = repository, expenseSpentAmountPort = port)(getActiveBudgetCommand(personId = "person-1"))

        assertNotNull(data)
        assertEquals(45_000, data.spentInCents)
        assertEquals("budget-1", data.budget.id)
        assertEquals(55_000, data.remainingInCents)
    }

    @Test
    fun `an active budget with nothing spent has a zero spent amount`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 31)))
        }

        val data = getActiveBudgetUseCase(clock = TODAY, repository = repository, expenseSpentAmountPort = expenseSpentAmountPortOf(0))(getActiveBudgetCommand(personId = "person-1"))

        assertNotNull(data)
        assertEquals(0, data.spentInCents)
    }

    @Test
    fun `no live budget covering today returns null, not an error`() {
        val repository = FakeBudgetRepository()

        val data = getActiveBudgetUseCase(clock = TODAY, repository = repository)(getActiveBudgetCommand(personId = "person-1"))

        assertNull(data)
    }

    @Test
    fun `an exceeded budget produces a negative remaining amount`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(personId = "person-1", amountInCents = 100_000, startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 31)))
        }

        val data = getActiveBudgetUseCase(clock = TODAY, repository = repository, expenseSpentAmountPort = expenseSpentAmountPortOf(130_000))(getActiveBudgetCommand(personId = "person-1"))

        assertNotNull(data)
        assertEquals(-30_000, data.remainingInCents)
    }

    @Test
    fun `the spent amount is asked for exactly the active budget's own period`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 31)))
        }
        val port = expenseSpentAmountPortOf(0)

        getActiveBudgetUseCase(clock = TODAY, repository = repository, expenseSpentAmountPort = port)(getActiveBudgetCommand(personId = "person-1"))

        verify(exactly = 1) { port("person-1", LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 31)) }
    }

    @Test
    fun `without a live budget covering today, the spent amount port is never called`() {
        val port = expenseSpentAmountPortOf(0)

        getActiveBudgetUseCase(clock = TODAY, repository = FakeBudgetRepository(), expenseSpentAmountPort = port)(getActiveBudgetCommand())

        verify(exactly = 0) { port(any(), any(), any()) }
    }

    @Test
    fun `the owner is the command's person, never a body-supplied id`() {
        val repository = FakeBudgetRepository().apply {
            created.add(budget(personId = "person-2", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 31)))
        }

        val data = getActiveBudgetUseCase(clock = TODAY, repository = repository)(getActiveBudgetCommand(personId = "person-1"))

        assertNull(data)
    }
}
