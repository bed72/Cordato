package com.bed.cordato.support

import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource

import org.flywaydb.core.Flyway

import org.jooq.DSLContext
import org.jooq.SQLDialect
import org.jooq.impl.DSL

import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName

/**
 * A real PostgreSQL for adapter tests. Starts a container, applies the same Flyway migrations
 * the app ships, and exposes a pooled jOOQ [DSLContext] — mirroring production wiring (Hikari +
 * Flyway + jOOQ) so tests exercise the true adapter path, UNIQUE constraint included.
 *
 * Intended to be started once per test class (in `@BeforeAll`) and [close]d in `@AfterAll`. The
 * pool ([maximumPoolSize] > 1) lets the concurrency test drive genuinely parallel writes.
 */
class PostgresHarness : AutoCloseable {
    private lateinit var dataSource: HikariDataSource
    private val container = PostgreSQLContainer<Nothing>(DockerImageName.parse(IMAGE))

    lateinit var dsl: DSLContext
        private set

    fun start(): PostgresHarness {
        container.start()
        dataSource = HikariDataSource(
            HikariConfig().apply {
                maximumPoolSize = 8
                jdbcUrl = container.jdbcUrl
                username = container.username
                password = container.password
            },
        )
        Flyway.configure().dataSource(dataSource).load().migrate()
        dsl = DSL.using(dataSource, SQLDialect.POSTGRES)
        return this
    }

    override fun close() {
        if (::dataSource.isInitialized) dataSource.close()
        container.stop()
    }

    private companion object {
        const val IMAGE = "postgres:18-alpine"
    }
}
