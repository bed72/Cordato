package com.bed.cordato.features.identity.infrastructure.repositories

import kotlin.test.Test
import kotlin.test.AfterTest
import kotlin.test.assertTrue
import kotlin.test.BeforeTest
import kotlin.test.assertFalse
import kotlin.test.assertEquals

import java.util.concurrent.Callable
import java.util.concurrent.TimeUnit
import java.util.concurrent.Executors
import java.util.concurrent.CyclicBarrier

import org.junit.jupiter.api.AfterAll
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.TestInstance

import com.bed.cordato.core.infrastructure.persistence.models.Tables.PERSON

import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

import com.bed.cordato.support.PostgresHarness

/**
 * Adapter tests for [PersistencePersonRepository] against a real PostgreSQL (Testcontainers). One
 * container per class, Flyway-migrated once; each test starts from an empty `person` table.
 * These prove durability, the query path, and — crucially — that the datastore-enforced
 * UNIQUE constraint resolves to the losing `false` outcome rather than leaking an exception.
 */
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class PersistencePersonRepositoryTest {

    private val harness = PostgresHarness()
    private lateinit var repository: PersistencePersonRepository

    @BeforeAll
    fun startContainer() {
        harness.start()
        repository = PersistencePersonRepository(harness.dsl)
    }

    @AfterAll
    fun stopContainer() = harness.close()

    @BeforeTest
    @AfterTest
    fun cleanTable() {
        harness.dsl.deleteFrom(PERSON).execute()
    }

    @Test
    fun `saved person is found by existsByEmail - an unknown email is not`() {
        val inserted = repository.signUp(personWith("alice@example.com"))

        assertTrue(inserted)
        assertTrue(repository.existsByEmail(email("alice@example.com")))
        assertFalse(repository.existsByEmail(email("nobody@example.com")))
    }

    @Test
    fun `a person survives being re-read from the datastore`() {
        repository.signUp(personWith("carol@example.com", id = "person-carol", name = "Carol"))

        // Read the raw row back to prove it was actually persisted (not just cached in-process).
        val row = harness.dsl.selectFrom(PERSON).where(PERSON.EMAIL.eq("carol@example.com")).fetchOne()

        assertEquals("Carol", row?.name)
        assertEquals("person-carol", row?.id)
        assertEquals(PersonStatusEnum.ACTIVE.name, row?.status)
    }

    @Test
    fun `a duplicate email is rejected as false and creates no second row`() {
        assertTrue(repository.signUp(personWith("bob@example.com", id = "person-1")))

        val second = repository.signUp(personWith("bob@example.com", id = "person-2"))

        assertFalse(second, "second signUp for the same e-mail must lose, not throw")
        assertEquals(1, personCount("bob@example.com"))
    }

    @Test
    fun `two concurrent signups for the same email leave exactly one row and one loser`() {
        val barrier = CyclicBarrier(2)
        val pool = Executors.newFixedThreadPool(2)

        fun race(id: String) = Callable {
            barrier.await() // release both threads into signUp at the same instant
            repository.signUp(personWith("dave@example.com", id = id))
        }

        try {
            val results = pool.invokeAll(listOf(race("person-a"), race("person-b")))
                .map { it.get(10, TimeUnit.SECONDS) }

            assertEquals(listOf(false, true), results.sorted(), "exactly one insert wins, one loses")
            assertEquals(1, personCount("dave@example.com"))
        } finally {
            pool.shutdownNow()
        }
    }

    private fun personCount(email: String): Int =
        harness.dsl.fetchCount(PERSON, PERSON.EMAIL.eq(email))

    private fun personWith(
        rawEmail: String,
        name: String = "Person",
        id: String = "person-$rawEmail",
    ) = PersonEntity(
        id = id,
        hash = "bcrypt:secret",
        email = email(rawEmail),
        status = PersonStatusEnum.ACTIVE,
        name = NameValueObject.of(name)!!,
    )

    private fun email(raw: String) = EmailValueObject.of(raw)!!
}
