package com.bed.cordato.support

import org.jooq.impl.DSL
import org.jooq.DSLContext
import org.jooq.SQLDialect
import org.flywaydb.core.Flyway

import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource

import org.testcontainers.utility.DockerImageName
import org.testcontainers.containers.PostgreSQLContainer

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
