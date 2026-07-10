package com.bed.cordato.features.identity.infrastructure.repositories

import kotlin.test.Test
import kotlin.test.AfterTest
import kotlin.test.assertNull
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
import org.junit.jupiter.api.Assumptions.assumeTrue

import org.testcontainers.DockerClientFactory

import com.bed.cordato.features.identity.factories.email
import com.bed.cordato.features.identity.factories.person

import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum

import com.bed.cordato.core.infrastructure.persistence.models.Tables.PERSON

import com.bed.cordato.support.PostgresHarness

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class PersistencePersonRepositoryTest {

    private val harness = PostgresHarness()
    private lateinit var repository: PersistencePersonRepository

    @BeforeAll
    fun startContainer() {
        // Testcontainers needs a Docker daemon; when none is reachable, skip (abort) rather than fail the
        // suite — this test only has meaning against a real PostgreSQL.
        assumeTrue(DockerClientFactory.instance().isDockerAvailable, "Docker unavailable; skipping container test")
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
        val inserted = repository.signUp(person(rawEmail = "alice@example.com"))

        assertTrue(inserted)
        assertTrue(repository.existsByEmail(email("alice@example.com")))
        assertFalse(repository.existsByEmail(email("nobody@example.com")))
    }

    @Test
    fun `a person survives being re-read from the datastore`() {
        repository.signUp(person(id = "person-carol", name = "Carol", rawEmail = "carol@example.com"))

        val row = harness.dsl.selectFrom(PERSON).where(PERSON.EMAIL.eq("carol@example.com")).fetchOne()

        assertEquals("Carol", row?.name)
        assertEquals("person-carol", row?.id)
        assertEquals(PersonStatusEnum.ACTIVE.name, row?.status)
    }

    @Test
    fun `a duplicate email is rejected as false and creates no second row`() {
        assertTrue(repository.signUp(person(id = "person-1", rawEmail = "bob@example.com")))

        val second = repository.signUp(person(id = "person-2", rawEmail = "bob@example.com"))

        assertEquals(1, personCount("bob@example.com"))
        assertFalse(second, "second signUp for the same e-mail must lose, not throw")
    }

    @Test
    fun `two concurrent signups for the same email leave exactly one row and one loser`() {
        val barrier = CyclicBarrier(2)
        val pool = Executors.newFixedThreadPool(2)

        fun race(id: String) = Callable {
            barrier.await()
            repository.signUp(person(id = id, rawEmail = "dave@example.com"))
        }

        try {
            val results = pool.invokeAll(listOf(race("person-a"), race("person-b")))
                .map { it.get(10, TimeUnit.SECONDS) }

            assertEquals(1, personCount("dave@example.com"))
            assertEquals(listOf(false, true), results.sorted(), "exactly one insert wins, one loses")
        } finally {
            pool.shutdownNow()
        }
    }

    @Test
    fun `findById returns the active person for a known id`() {
        repository.signUp(person(id = "person-erin", name = "Erin", rawEmail = "erin@example.com"))

        val found = repository.findById("person-erin")

        assertEquals("person-erin", found?.id)
        assertEquals("Erin", found?.name?.value)
        assertEquals("erin@example.com", found?.email?.value)
    }

    @Test
    fun `findById returns absence for an unknown id`() {
        assertNull(repository.findById("nobody"))
    }

    @Test
    fun `findById returns absence for a non-active person, indistinguishable from unknown`() {
        repository.signUp(person(id = "person-frank", rawEmail = "frank@example.com", status = PersonStatusEnum.DELETED))

        assertNull(repository.findById("person-frank"))
    }

    private fun personCount(email: String): Int =
        harness.dsl.fetchCount(PERSON, PERSON.EMAIL.eq(email))
}
