package com.bed.cordato.core.infrastructure.http.rate_limit.filters

import java.time.Instant
import java.time.Duration

import jakarta.inject.Inject

import kotlin.test.Test
import kotlin.test.BeforeTest
import kotlin.test.assertEquals

import io.micronaut.test.extensions.junit5.annotation.MicronautTest

import org.junit.jupiter.api.TestInstance

import io.micronaut.context.annotation.Property

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpRequest
import io.micronaut.http.client.HttpClient
import io.micronaut.http.client.annotation.Client
import io.micronaut.http.client.exceptions.HttpClientResponseException

import com.bed.cordato.core.factories.FakeClockPort
import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse

// Kept in sync by hand with the @Property values below (annotation arguments must be compile-time
// constants, so the numeric literal can't be derived from these at the annotation site).
private const val GENERAL_LIMIT = 3
private const val SENSITIVE_LIMIT = 2

/**
 * Exercises `RateLimitFilter` end-to-end through the real filter chain, following
 * `AuthenticatedFilterTest`'s shape: `FakeCachePort` (already globally wired) and a `FakeClockPort`
 * (scoped to this spec only, via `FakeClockPortFactory`'s `spec.name` gate) stand in for Valkey and wall
 * time, `AuthProbeController`'s routes drive requests, and small `@Property` overrides make the limits
 * cheap to exceed deterministically. `freshWindow` advances the clock by a full day before every test —
 * far past any window used here — so no test's counters collide with another's, without needing to reset
 * the shared `FakeCachePort`. This requires `instant` to accumulate across test methods rather than reset
 * for each one, hence `PER_CLASS` (JUnit5's default `PER_METHOD` would re-run every `@BeforeTest` from the
 * same starting `instant`, landing every test on the identical window key).
 */
@MicronautTest
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
@Property(name = "spec.name", value = "RateLimitFilterTest")
@Property(name = "cordato.rate-limit.general.limit", value = "3")
@Property(name = "cordato.rate-limit.general.window", value = "PT1M")
@Property(name = "cordato.rate-limit.sensitive.limit", value = "2")
@Property(name = "cordato.rate-limit.sensitive.window", value = "PT1M")
class RateLimitFilterTest {

    @Inject
    lateinit var clock: FakeClockPort

    @Inject
    @field:Client("/")
    lateinit var client: HttpClient

    private var instant = Instant.parse("2026-01-01T00:00:00Z")

    @BeforeTest
    fun freshWindow() {
        instant = instant.plus(Duration.ofDays(1))
        clock.advanceTo(instant)
    }

    private fun request(path: String, authorization: String? = null): HttpRequest<Any> {
        val request = HttpRequest.GET<Any>(path)
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun retrieve(path: String): String = client.toBlocking().retrieve(request(path))

    private fun reject(path: String, authorization: String? = null): HttpClientResponseException =
        try {
            client.toBlocking().exchange(request(path, authorization), String::class.java)
            error("Expected the request to be refused with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    @Test
    fun `requests within the general limit pass through, the next one is refused with 429`() {
        repeat(GENERAL_LIMIT) { assertEquals("open", retrieve("/v1/probe/open")) }

        val exception = reject("/v1/probe/open")

        assertEquals(HttpStatus.TOO_MANY_REQUESTS, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals("429", item.status)
        assertEquals(null, item.source)
        assertEquals("RATE_LIMITED", item.code)
        assertEquals("60", exception.response.headers.get("Retry-After"))
    }

    @Test
    fun `a fresh window resets the count independent of the previous window`() {
        repeat(GENERAL_LIMIT) { retrieve("/v1/probe/open") }
        reject("/v1/probe/open")

        instant = instant.plus(Duration.ofMinutes(1))
        clock.advanceTo(instant)

        assertEquals("open", retrieve("/v1/probe/open"))
    }

    @Test
    fun `the sensitive tier is a separate, stricter budget independent of general`() {
        repeat(SENSITIVE_LIMIT) { assertEquals("sensitive", retrieve("/v1/probe/sensitive")) }
        val exception = reject("/v1/probe/sensitive")

        assertEquals(HttpStatus.TOO_MANY_REQUESTS, exception.status)
        assertEquals("open", retrieve("/v1/probe/open"), "the exhausted sensitive counter leaked into general")
    }

    @Test
    fun `rate limiting runs before authentication, over the general limit an unauthenticated flood gets 429 not 401`() {
        repeat(GENERAL_LIMIT) { i ->
            val exception = reject("/v1/probe/whoami")
            assertEquals(HttpStatus.UNAUTHORIZED, exception.status, "request #${i + 1} should still be under budget")
        }

        val exception = reject("/v1/probe/whoami")

        assertEquals(HttpStatus.TOO_MANY_REQUESTS, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals("RATE_LIMITED", item.code)
    }
}
