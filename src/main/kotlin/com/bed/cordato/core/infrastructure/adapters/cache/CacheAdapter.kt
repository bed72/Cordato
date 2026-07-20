package com.bed.cordato.core.infrastructure.adapters.cache

import java.time.Duration

import io.lettuce.core.SetArgs
import io.lettuce.core.RedisClient
import io.lettuce.core.api.StatefulRedisConnection

import com.bed.cordato.core.application.driven.ports.CachePort

/**
 * Durable [CachePort] over a Valkey (Redis-compatible) connection via the Lettuce client — the only place
 * in the codebase the Lettuce type is named ([connect] is how [com.bed.cordato.core.main.CoreFactory] builds
 * one from config, so it never has to name a Lettuce type itself). [connection] is a long-lived, thread-safe
 * connection (one per process); commands run through its synchronous API, which is all this port needs.
 *
 * A client-level failure (connection lost, protocol error) propagates as-is: this adapter has no opinion on
 * whether that should degrade to a miss — that policy belongs to the caller (the expense cache decorator).
 */
class CacheAdapter(connection: StatefulRedisConnection<String, String>) : CachePort {

    private val commands = connection.sync()

    override fun get(key: String): String? = commands.get(key)

    override fun set(key: String, value: String, ttl: Duration) {
        commands.set(key, value, SetArgs.Builder.ex(ttl.seconds))
    }

    override fun increment(key: String): Long = commands.incr(key)

    companion object {
        fun connect(host: String, port: Int): CacheAdapter =
            CacheAdapter(RedisClient.create("redis://$host:$port").connect())
    }
}
