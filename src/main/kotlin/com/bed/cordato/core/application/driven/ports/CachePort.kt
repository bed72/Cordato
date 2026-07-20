package com.bed.cordato.core.application.driven.ports

import java.time.Duration

/**
 * Driven port for the distributed cache kernel — a pure, client-agnostic contract features consume to
 * accelerate a read without knowing Valkey/Redis exists. Implemented in core/infrastructure by
 * [com.bed.cordato.core.infrastructure.adapters.cache.CacheAdapter].
 *
 * [get] returns the value stored under [key], or `null` when the key is absent or expired — never an
 * exception for a plain miss. [set] stores [value] under [key] with a [ttl] after which it expires on its
 * own. [increment] atomically increments the named counter at [key] and returns its new value — a counter
 * never before incremented starts from `0` (so the first call returns `1`); this is the primitive
 * generation-based invalidation is built on.
 *
 * A genuine client failure (the datastore unreachable, a protocol error) propagates as an exception rather
 * than being swallowed into a value here — the caller (a repository decorator) decides whether that failure
 * degrades to a miss.
 */
interface CachePort {
    fun get(key: String): String?

    fun set(key: String, value: String, ttl: Duration)

    fun increment(key: String): Long
}
