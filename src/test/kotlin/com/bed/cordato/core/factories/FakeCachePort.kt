package com.bed.cordato.core.factories

import java.time.Duration

import com.bed.cordato.core.application.driven.ports.CachePort

/**
 * In-memory [CachePort] fake for tests: a single [values] map, no TTL enforcement (a test that cares about
 * expiry exercises the real [com.bed.cordato.core.infrastructure.adapters.cache.CacheAdapter]
 * instead). [increment] shares that same map — mirroring real Redis/Valkey, where `INCR` and `GET` operate
 * on the same keyspace (a generation counter bumped by `increment` must be readable back by [get]) — storing
 * the running total as its string form. Setting [available] to `false` makes every operation throw, standing
 * in for a genuinely unreachable cache so a caller's degrade-to-miss behavior can be exercised without a real
 * Valkey outage. [expire] tracks only which keys have had a TTL armed (no actual expiry, mirroring [set]'s
 * TTL-less style) — enough to assert `NX` semantics without a real Valkey.
 */
class FakeCachePort : CachePort {
    private val armedTtls = mutableSetOf<String>()
    private val values = mutableMapOf<String, String>()

    var available = true

    override fun get(key: String): String? {
        check(available) { "cache unavailable" }
        return values[key]
    }

    override fun set(key: String, value: String, ttl: Duration) {
        check(available) { "cache unavailable" }
        values[key] = value
    }

    override fun increment(key: String): Long {
        check(available) { "cache unavailable" }
        val next = (values[key]?.toLong() ?: 0L) + 1
        values[key] = next.toString()
        return next
    }

    override fun expire(key: String, ttl: Duration) {
        check(available) { "cache unavailable" }
        armedTtls.add(key)
    }
}
