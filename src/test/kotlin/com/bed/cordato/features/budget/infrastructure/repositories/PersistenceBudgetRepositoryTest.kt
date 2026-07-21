package com.bed.cordato.features.budget.infrastructure.repositories

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.AfterTest
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.BeforeTest
import kotlin.test.assertFalse
import kotlin.test.assertEquals

import org.junit.jupiter.api.AfterAll
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.TestInstance
import org.junit.jupiter.api.Assumptions.assumeTrue

import org.testcontainers.DockerClientFactory

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
        // Testcontainers needs a Docker daemon; when none is reachable, skip (abort) rather than fail the
        // suite — this test only has meaning against a real PostgreSQL.
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
            personId = "person-1",
            amountInCents = 259_900,
            note = "Mercado",
            startDate = LocalDate.of(2026, 7, 1),
            endDate = LocalDate.of(2026, 7, 31),
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
                startDate = LocalDate.of(2026, 7, 1),
                endDate = LocalDate.of(2026, 7, 15),
                status = BudgetStatusEnum.DELETED,
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
}
