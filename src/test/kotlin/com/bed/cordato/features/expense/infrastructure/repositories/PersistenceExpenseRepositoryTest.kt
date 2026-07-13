package com.bed.cordato.features.expense.infrastructure.repositories

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.AfterTest
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.BeforeTest
import kotlin.test.assertEquals

import org.junit.jupiter.api.AfterAll
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.TestInstance
import org.junit.jupiter.api.Assumptions.assumeTrue

import org.testcontainers.DockerClientFactory

import com.bed.cordato.core.infrastructure.persistence.models.Tables.EXPENSE

import com.bed.cordato.features.expense.factories.expense
import com.bed.cordato.features.expense.infrastructure.repositories.mappers.toEntity

import com.bed.cordato.support.PostgresHarness

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class PersistenceExpenseRepositoryTest {

    private val harness = PostgresHarness()
    private lateinit var repository: PersistenceExpenseRepository

    @BeforeAll
    fun startContainer() {
        // Testcontainers needs a Docker daemon; when none is reachable, skip (abort) rather than fail the
        // suite — this test only has meaning against a real PostgreSQL.
        assumeTrue(DockerClientFactory.instance().isDockerAvailable, "Docker unavailable; skipping container test")
        harness.start()
        repository = PersistenceExpenseRepository(harness.dsl)
    }

    @AfterAll
    fun stopContainer() = harness.close()

    @BeforeTest
    @AfterTest
    fun cleanTable() {
        harness.dsl.deleteFrom(EXPENSE).execute()
    }

    @Test
    fun `a created expense survives being re-read from the datastore`() {
        val stored = expense(
            id = "expense-1",
            personId = "person-1",
            amountInCents = 2_599,
            description = "Mercado",
            date = LocalDate.of(2026, 7, 1),
        )

        repository.create(stored)

        val reread = harness.dsl.selectFrom(EXPENSE).where(EXPENSE.ID.eq("expense-1")).fetchOne()!!.toEntity()
        assertEquals(stored, reread)
    }

    @Test
    fun `an expense with no description is stored with a null column`() {
        repository.create(expense(id = "expense-2", description = null))

        val row = harness.dsl.selectFrom(EXPENSE).where(EXPENSE.ID.eq("expense-2")).fetchOne()

        assertNull(row?.description)
    }

    @Test
    fun `the amount is stored as an exact integer number of cents`() {
        repository.create(expense(id = "expense-3", amountInCents = 199))

        val row = harness.dsl.selectFrom(EXPENSE).where(EXPENSE.ID.eq("expense-3")).fetchOne()

        assertEquals(199L, row?.amountCents)
    }

    @Test
    fun `the expense carries no budget reference — the table has only the raw fact columns`() {
        val columns = EXPENSE.fields().map { it.name }.toSet()

        assertEquals(setOf("id", "person_id", "amount_cents", "spent_on", "description"), columns)
    }

    @Test
    fun `findByPerson returns only the owner's expenses, ordered by spent_on desc then id desc`() {
        // Two owners; for person-1, two expenses share a day so the id tie-break decides their order.
        repository.create(expense(id = "a", personId = "person-1", date = LocalDate.of(2026, 7, 1)))
        repository.create(expense(id = "b", personId = "person-1", date = LocalDate.of(2026, 7, 10)))
        repository.create(expense(id = "c", personId = "person-1", date = LocalDate.of(2026, 7, 10)))
        repository.create(expense(id = "z", personId = "person-2", date = LocalDate.of(2026, 7, 20)))

        val listed = repository.findByPerson("person-1")

        // Newest day first (b/c on the 10th before a on the 1st); same-day tie broken by id desc (c before b);
        // person-2's expense never leaks in.
        assertEquals(listOf("c", "b", "a"), listed.map { it.id })
        assertTrue(listed.all { it.personId == "person-1" })
    }

    @Test
    fun `findByPerson returns an empty list when the person has no expenses`() {
        repository.create(expense(id = "a", personId = "someone-else"))

        assertTrue(repository.findByPerson("person-1").isEmpty())
    }
}
