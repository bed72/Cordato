package com.bed.cordato.support

import io.lettuce.core.RedisClient
import io.lettuce.core.api.StatefulRedisConnection

import org.testcontainers.containers.GenericContainer
import org.testcontainers.utility.DockerImageName

class ValkeyHarness : AutoCloseable {
    private lateinit var client: RedisClient
    private val container = GenericContainer<Nothing>(DockerImageName.parse(IMAGE)).apply {
        withExposedPorts(PORT)
    }

    lateinit var connection: StatefulRedisConnection<String, String>
        private set

    fun start(): ValkeyHarness {
        container.start()
        client = RedisClient.create("redis://${container.host}:${container.getMappedPort(PORT)}")
        connection = client.connect()
        return this
    }

    override fun close() {
        if (::connection.isInitialized) connection.close()
        if (::client.isInitialized) client.shutdown()
        container.stop()
    }

    private companion object {
        const val PORT = 6379
        const val IMAGE = "valkey/valkey:8-alpine"
    }
}
