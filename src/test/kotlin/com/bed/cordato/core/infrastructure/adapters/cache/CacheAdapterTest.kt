package com.bed.cordato.core.infrastructure.adapters.cache

import java.time.Duration

import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertEquals

import org.junit.jupiter.api.AfterAll
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.TestInstance
import org.junit.jupiter.api.Assumptions.assumeTrue

import org.testcontainers.DockerClientFactory

import com.bed.cordato.support.ValkeyHarness

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class CacheAdapterTest {

    private val harness = ValkeyHarness()
    private lateinit var adapter: CacheAdapter

    @BeforeAll
    fun startContainer() {
        // Testcontainers needs a Docker daemon; when none is reachable, skip (abort) rather than fail the
        // suite — this test only has meaning against a real Valkey.
        assumeTrue(DockerClientFactory.instance().isDockerAvailable, "Docker unavailable; skipping container test")
        harness.start()
        adapter = CacheAdapter(harness.connection)
    }

    @AfterAll
    fun stopContainer() = harness.close()

    @Test
    fun `a value written with a TTL is read back`() {
        adapter.set("greeting", "hello", Duration.ofSeconds(30))

        assertEquals("hello", adapter.get("greeting"))
    }

    @Test
    fun `a value expires once its TTL elapses`() {
        adapter.set("short-lived", "gone-soon", Duration.ofSeconds(1))

        Thread.sleep(1_500)

        assertNull(adapter.get("short-lived"))
    }

    @Test
    fun `a key never written is absent, not an error`() {
        assertNull(adapter.get("never-written"))
    }

    @Test
    fun `incrementing a counter is atomic and a fresh counter starts from zero`() {
        val first = adapter.increment("hits")
        val second = adapter.increment("hits")

        assertEquals(1L, first)
        assertEquals(2L, second)
    }
}
