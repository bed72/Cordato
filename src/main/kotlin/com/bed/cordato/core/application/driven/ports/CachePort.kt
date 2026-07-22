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
 * generation-based invalidation is built on. [expire] arms a TTL on an already-written key (e.g. a counter
 * [increment] just bumped) without touching its value; this is the primitive the fixed-window rate limiter
 * is built on.
 *
 * A genuine client failure (the datastore unreachable, a protocol error) propagates as an exception rather
 * than being swallowed into a value here — the caller (a repository decorator) decides whether that failure
 * degrades to a miss.
 */
interface CachePort {
    fun get(key: String): String?

    fun increment(key: String): Long

    fun set(key: String, value: String, ttl: Duration)

    /**
     * Arms a TTL on [key] — `EXPIRE ... NX` semantics: only if [key] does not already have one, and never
     * touching its current value. Idempotent, so a caller may call it unconditionally after every
     * [increment] without knowing whether this was the window's first hit — whichever call lands first wins,
     * and every later call on the same key is a safe no-op rather than overwriting an already-running TTL.
     */
    fun expire(key: String, ttl: Duration)
}
