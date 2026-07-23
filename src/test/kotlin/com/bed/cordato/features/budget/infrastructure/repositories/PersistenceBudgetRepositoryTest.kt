package com.bed.cordato.features.budget.infrastructure.repositories

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.AfterTest
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.BeforeTest
import kotlin.test.assertFalse
import kotlin.test.assertEquals

import org.testcontainers.DockerClientFactory

import org.junit.jupiter.api.AfterAll
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.TestInstance
import org.junit.jupiter.api.Assumptions.assumeTrue


import com.bed.cordato.core.infrastructure.persistence.models.Tables.BUDGET

import com.bed.cordato.features.budget.factories.budget
import com.bed.cordato.features.budget.domain.enums.BudgetStatusEnum
import com.bed.cordato.features.budget.infrastructure.repositories.mappers.toEntity

import com.bed.cordato.support.PostgresHarness

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class PersistenceBudgetRepositoryTest {

    private val harness = PostgresHarness()
    private lateinit var repository: PersistenceBudgetRepository

    @BeforeAll
    fun startContainer() {
        assumeTrue(DockerClientFactory.instance().isDockerAvailable, "Docker unavailable; skipping container test")
        harness.start()
        repository = PersistenceBudgetRepository(harness.dsl)
    }

    @AfterAll
    fun stopContainer() = harness.close()

    @BeforeTest
    @AfterTest
    fun cleanTable() {
        harness.dsl.deleteFrom(BUDGET).execute()
    }

    @Test
    fun `a created budget survives being re-read from the datastore`() {
        val stored = budget(
            id = "budget-1",
            note = "Mercado",
            personId = "person-1",
            amountInCents = 259_900,
            endDate = LocalDate.of(2026, 7, 31),
            startDate = LocalDate.of(2026, 7, 1),
        )

        repository.create(stored)

        val reread = harness.dsl.selectFrom(BUDGET).where(BUDGET.ID.eq("budget-1")).fetchOne()!!.toEntity()
        assertEquals(stored, reread)
    }

    @Test
    fun `a budget with no note is stored with a null column`() {
        repository.create(budget(id = "budget-2", note = null))

        val row = harness.dsl.selectFrom(BUDGET).where(BUDGET.ID.eq("budget-2")).fetchOne()

        assertNull(row?.note)
    }

    @Test
    fun `the amount is stored as an exact integer number of cents`() {
        repository.create(budget(id = "budget-3", amountInCents = 199))

        val row = harness.dsl.selectFrom(BUDGET).where(BUDGET.ID.eq("budget-3")).fetchOne()

        assertEquals(199L, row?.amountCents)
    }

    @Test
    fun `the budget carries no expense reference — the table has only the raw ceiling columns`() {
        val columns = BUDGET.fields().map { it.name }.toSet()

        assertEquals(setOf("id", "person_id", "amount_cents", "start_date", "end_date", "note", "status"), columns)
    }

    @Test
    fun `hasOverlappingLiveBudget detects boundary overlap`() {
        repository.create(budget(id = "a", personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 15)))

        val overlaps = repository.hasOverlappingLiveBudget("person-1", LocalDate.of(2026, 7, 15), LocalDate.of(2026, 7, 31))

        assertTrue(overlaps)
    }

    @Test
    fun `hasOverlappingLiveBudget does not detect overlap between adjacent intervals`() {
        repository.create(budget(id = "a", personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 15)))

        val overlaps = repository.hasOverlappingLiveBudget("person-1", LocalDate.of(2026, 7, 16), LocalDate.of(2026, 7, 31))

        assertFalse(overlaps)
    }

    @Test
    fun `hasOverlappingLiveBudget ignores removed budgets`() {
        repository.create(
            budget(
                id = "a",
                personId = "person-1",
                status = BudgetStatusEnum.DELETED,
                endDate = LocalDate.of(2026, 7, 15),
                startDate = LocalDate.of(2026, 7, 1),
            ),
        )

        val overlaps = repository.hasOverlappingLiveBudget("person-1", LocalDate.of(2026, 7, 10), LocalDate.of(2026, 7, 20))

        assertFalse(overlaps)
    }

    @Test
    fun `hasOverlappingLiveBudget never compares budgets across different people`() {
        repository.create(budget(id = "a", personId = "person-2", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 15)))

        val overlaps = repository.hasOverlappingLiveBudget("person-1", LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 15))

        assertFalse(overlaps)
    }

    @Test
    fun `findLiveBudgetCovering finds the live budget whose period covers the given date`() {
        repository.create(budget(id = "a", personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 31)))

        val found = repository.findLiveBudgetCovering("person-1", LocalDate.of(2026, 7, 15))

        assertEquals("a", found?.id)
    }

    @Test
    fun `findLiveBudgetCovering treats both period boundaries as included`() {
        repository.create(budget(id = "a", personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 31)))

        assertEquals("a", repository.findLiveBudgetCovering("person-1", LocalDate.of(2026, 7, 1))?.id)
        assertEquals("a", repository.findLiveBudgetCovering("person-1", LocalDate.of(2026, 7, 31))?.id)
    }

    @Test
    fun `findLiveBudgetCovering returns null when no live budget covers the given date`() {
        repository.create(budget(id = "a", personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 15)))

        val found = repository.findLiveBudgetCovering("person-1", LocalDate.of(2026, 8, 1))

        assertNull(found)
    }

    @Test
    fun `findLiveBudgetCovering never returns a removed budget, even if it covers the date`() {
        repository.create(
            budget(
                id = "a",
                personId = "person-1",
                status = BudgetStatusEnum.DELETED,
                endDate = LocalDate.of(2026, 7, 31),
                startDate = LocalDate.of(2026, 7, 1),
            ),
        )

        val found = repository.findLiveBudgetCovering("person-1", LocalDate.of(2026, 7, 15))

        assertNull(found)
    }

    @Test
    fun `findLiveBudgetCovering never compares budgets across different people`() {
        repository.create(budget(id = "a", personId = "person-2", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 31)))

        val found = repository.findLiveBudgetCovering("person-1", LocalDate.of(2026, 7, 15))

        assertNull(found)
    }

    @Test
    fun `findAllLiveBudgets finds every live budget of the person`() {
        repository.create(budget(id = "a", personId = "person-1", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 15)))
        repository.create(budget(id = "b", personId = "person-1", startDate = LocalDate.of(2026, 7, 16), endDate = LocalDate.of(2026, 7, 31)))

        val found = repository.findAllLiveBudgets("person-1")

        assertEquals(setOf("a", "b"), found.map { it.id }.toSet())
    }

    @Test
    fun `findAllLiveBudgets returns an empty list for a person with no live budget`() {
        val found = repository.findAllLiveBudgets("person-1")

        assertEquals(emptyList(), found)
    }

    @Test
    fun `findAllLiveBudgets never returns a removed budget`() {
        repository.create(
            budget(
                id = "a",
                personId = "person-1",
                status = BudgetStatusEnum.DELETED,
                endDate = LocalDate.of(2026, 7, 31),
                startDate = LocalDate.of(2026, 7, 1),
            ),
        )

        val found = repository.findAllLiveBudgets("person-1")

        assertEquals(emptyList(), found)
    }

    @Test
    fun `findAllLiveBudgets never returns budgets of another person`() {
        repository.create(budget(id = "a", personId = "person-2", startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 31)))

        val found = repository.findAllLiveBudgets("person-1")

        assertEquals(emptyList(), found)
    }
}
