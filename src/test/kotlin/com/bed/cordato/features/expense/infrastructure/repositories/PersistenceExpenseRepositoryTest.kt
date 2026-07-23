package com.bed.cordato.features.expense.infrastructure.repositories

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.AfterTest
import kotlin.test.assertNull
import kotlin.test.BeforeTest
import kotlin.test.assertEquals

import org.testcontainers.DockerClientFactory

import org.junit.jupiter.api.AfterAll
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.TestInstance
import org.junit.jupiter.api.Assumptions.assumeTrue

import com.bed.cordato.core.infrastructure.persistence.models.Tables.EXPENSE

import com.bed.cordato.features.expense.factories.expense
import com.bed.cordato.features.expense.infrastructure.repositories.mappers.toEntity
import com.bed.cordato.features.expense.domain.value_objects.ExpenseCursorValueObject

import com.bed.cordato.support.PostgresHarness

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class PersistenceExpenseRepositoryTest {

    private val harness = PostgresHarness()
    private lateinit var repository: PersistenceExpenseRepository

    @BeforeAll
    fun startContainer() {
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
        val older = expense(id = "a", personId = "person-1", date = LocalDate.of(2026, 7, 1))
        val other = expense(id = "d", personId = "person-2", date = LocalDate.of(2026, 7, 20))
        val newerLow = expense(id = "b", personId = "person-1", date = LocalDate.of(2026, 7, 10))
        val newerHigh = expense(id = "c", personId = "person-1", date = LocalDate.of(2026, 7, 10))

        listOf(older, newerLow, other, newerHigh).forEach(repository::create)

        val listed = repository.findByPerson("person-1", after = null, limit = 10)

        assertEquals(listOf(newerHigh, newerLow, older), listed)
    }

    @Test
    fun `findByPerson returns an empty list for a person with no expenses`() {
        repository.create(expense(id = "a", personId = "person-2"))

        assertEquals(emptyList(), repository.findByPerson("person-1", after = null, limit = 10))
    }

    @Test
    fun `findByPerson respects the limit, returning at most that many items`() {
        listOf("a", "b", "c").forEach { id ->
            repository.create(expense(id = id, personId = "person-1", date = LocalDate.of(2026, 7, 1)))
        }

        val listed = repository.findByPerson("person-1", after = null, limit = 2)

        assertEquals(2, listed.size)
    }

    @Test
    fun `findByPerson continues strictly after the given cursor position, without repeats`() {
        val middle = expense(id = "b", personId = "person-1", date = LocalDate.of(2026, 7, 5))
        val oldest = expense(id = "a", personId = "person-1", date = LocalDate.of(2026, 7, 1))
        val newest = expense(id = "c", personId = "person-1", date = LocalDate.of(2026, 7, 10))

        listOf(oldest, newest, middle).forEach(repository::create)

        val cursor = ExpenseCursorValueObject.of(middle.date.value, middle.id)
        val listed = repository.findByPerson("person-1", after = cursor, limit = 10)

        assertEquals(listOf(oldest), listed)
    }

    @Test
    fun `findByPerson returns an empty list once the cursor has exhausted the owner's expenses`() {
        val only = expense(id = "a", personId = "person-1", date = LocalDate.of(2026, 7, 1))
        repository.create(only)

        val cursor = ExpenseCursorValueObject.of(only.date.value, only.id)
        val listed = repository.findByPerson("person-1", after = cursor, limit = 10)

        assertEquals(emptyList(), listed)
    }

    @Test
    fun `sumAmountInRange sums only the person's expenses within the inclusive date range`() {
        repository.create(expense(id = "a", personId = "person-1", amountInCents = 1_000, date = LocalDate.of(2026, 7, 1)))
        repository.create(expense(id = "b", personId = "person-1", amountInCents = 2_000, date = LocalDate.of(2026, 7, 31)))
        repository.create(expense(id = "c", personId = "person-1", amountInCents = 5_000, date = LocalDate.of(2026, 8, 1)))
        repository.create(expense(id = "d", personId = "person-2", amountInCents = 9_000, date = LocalDate.of(2026, 7, 15)))

        val total = repository.sumAmountInRange("person-1", LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 31))

        assertEquals(3_000, total)
    }

    @Test
    fun `sumAmountInRange is zero for a person with nothing in range`() {
        repository.create(expense(id = "a", personId = "person-1", date = LocalDate.of(2026, 6, 1)))

        val total = repository.sumAmountInRange("person-1", LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 31))

        assertEquals(0, total)
    }

    @Test
    fun `sumAmountInRange is zero for a person with no expenses at all`() {
        val total = repository.sumAmountInRange("person-1", LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 31))

        assertEquals(0, total)
    }

    @Test
    fun `sumAmount sums all of the person's expenses regardless of date`() {
        repository.create(expense(id = "a", personId = "person-1", amountInCents = 1_000, date = LocalDate.of(2026, 7, 1)))
        repository.create(expense(id = "b", personId = "person-1", amountInCents = 2_000, date = LocalDate.of(2026, 12, 31)))
        repository.create(expense(id = "c", personId = "person-2", amountInCents = 9_000, date = LocalDate.of(2026, 7, 15)))

        val total = repository.sumAmount("person-1")

        assertEquals(3_000, total)
    }

    @Test
    fun `sumAmount is zero for a person with no expenses at all`() {
        val total = repository.sumAmount("person-1")

        assertEquals(0, total)
    }
}
