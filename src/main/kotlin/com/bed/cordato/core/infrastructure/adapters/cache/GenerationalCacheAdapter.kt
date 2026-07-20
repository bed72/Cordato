package com.bed.cordato.core.infrastructure.adapters.cache

import java.time.Duration

import org.slf4j.Logger
import org.slf4j.LoggerFactory

import com.bed.cordato.core.application.driven.ports.CachePort

/**
 * The generation-based read-through/write-through/invalidation policy behind every "list my own X" cache
 * decorator — the shared kernel counterpart of [CachePort] itself: features never talk to [cache] directly,
 * they get a [GenerationalCacheAdapter] scoped to their own [prefix] (e.g. `"expenses"`) and [ttl].
 *
 * **Read** ([readThrough]): the cache key embeds the owner's current *generation* (`{prefix}:{ownerId}:gen`,
 * read via [CachePort.get], defaulting to `0` when absent) plus the caller-supplied [suffix] (e.g. page
 * position and limit), so a hit can only ever come from the current generation.
 *
 * **Write** ([writeThrough]): stores under that same generation-scoped key with [ttl].
 *
 * **Invalidation** ([invalidate]): increments the owner's generation — every key cached under the old
 * generation becomes unreachable immediately (and expires by [ttl] as a floor). A caller's write path calls
 * this after persisting.
 *
 * **Failure posture**: any [CachePort] failure (read, write, or the generation lookup) is caught and logged,
 * then treated as a miss/no-op — the cache accelerates, it is never the source of truth, so the cache being
 * down must never fail a read or a write.
 */
class GenerationalCacheAdapter(
    private val ttl: Duration,
    private val prefix: String,
    private val cache: CachePort,
) {
    fun <T> readThrough(ownerId: String, suffix: String, deserialize: (String) -> T?): T? {
        val key = key(ownerId, suffix)

        return runCatching { cache.get(key) }
            .onFailure { logger.warn("Cache read failed for key {}; falling back to persistence", key, it) }
            .getOrNull()
            ?.let { value -> runCatching { deserialize(value) }.getOrNull() }
    }

    fun <T> writeThrough(ownerId: String, suffix: String, value: T, serialize: (T) -> String) {
        val key = key(ownerId, suffix)

        runCatching { cache.set(key, serialize(value), ttl) }
            .onFailure { logger.warn("Cache write failed for key {}", key, it) }
    }

    fun invalidate(ownerId: String) {
        runCatching { cache.increment(generationKey(ownerId)) }
            .onFailure { logger.warn("Cache invalidation failed for owner {}", ownerId, it) }
    }

    private fun key(ownerId: String, suffix: String): String {
        val generation = runCatching { cache.get(generationKey(ownerId)) }.getOrNull() ?: "0"
        return "$prefix:$ownerId:v$generation:$suffix"
    }

    private fun generationKey(ownerId: String): String = "$prefix:$ownerId:gen"

    private companion object {
        val logger: Logger = LoggerFactory.getLogger(GenerationalCacheAdapter::class.java)
    }
}
