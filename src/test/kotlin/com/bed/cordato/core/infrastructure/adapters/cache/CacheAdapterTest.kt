package com.bed.cordato.core.infrastructure.adapters.cache

import java.time.Duration

import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertEquals

import org.testcontainers.DockerClientFactory

import org.junit.jupiter.api.AfterAll
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.TestInstance
import org.junit.jupiter.api.Assumptions.assumeTrue

import com.bed.cordato.support.ValkeyHarness

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
internal class CacheAdapterTest {

    private val harness = ValkeyHarness()
    private lateinit var adapter: CacheAdapter

    @BeforeAll
    fun startContainer() {
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

    @Test
    fun `expire arms a TTL on a key that has none`() {
        adapter.increment("no-ttl")
        adapter.expire("no-ttl", Duration.ofSeconds(1))

        Thread.sleep(1_500)

        assertNull(adapter.get("no-ttl"))
    }

    @Test
    fun `expire is a no-op on a key that already has a TTL, preserving the original`() {
        adapter.set("already-armed", "value", Duration.ofSeconds(30))
        adapter.expire("already-armed", Duration.ofMillis(1))

        Thread.sleep(50)

        assertEquals("value", adapter.get("already-armed"), "a shorter TTL overwrote the one already running")
    }

    @Test
    fun `expire preserves the counter value it arms a TTL over`() {
        val count = adapter.increment("armed-counter")
        adapter.expire("armed-counter", Duration.ofSeconds(30))

        assertEquals(count.toString(), adapter.get("armed-counter"))
    }
}
