package com.bed.cordato.core.main

import javax.sql.DataSource

import jakarta.inject.Singleton

import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource

import io.micronaut.context.annotation.Factory

import org.flywaydb.core.Flyway

import org.jooq.DSLContext
import org.jooq.SQLDialect
import org.jooq.impl.DSL

import com.bed.cordato.core.application.ports.ClockPort
import com.bed.cordato.core.application.ports.IdGeneratorPort
import com.bed.cordato.core.infrastructure.adapters.ClockAdapter
import com.bed.cordato.core.infrastructure.adapters.IdGeneratorAdapter
import com.bed.cordato.core.infrastructure.persistence.configurations.DatabaseConfiguration

/**
 * Core's DI factory — the shared kernel every bounded context inherits: determinism ports
 * (clock, id generation) and the shared persistence wiring. Lives in core's own `main`
 * subpackage; the root `com.bed.cordato.main.Main` starts one `ApplicationContext` that
 * discovers this factory alongside each context's. `domain` and `application` never import
 * Micronaut — only this `main` layer wires. The pure ports/adapters carry no annotations,
 * so each `@Singleton` method here is the single explicit place they are constructed.
 *
 * A pooled [DataSource] and a single [DSLContext] are the only things a feature's repositories
 * depend on — jOOQ/JDBC never leak past infrastructure. Flyway migrations (the schema source of
 * truth) run when the pool is first built, so the datasource is only ever handed out against an
 * up-to-date schema. Single-instance deploys today; a multi-instance migration gate is deferred
 * (see design.md risks).
 */
@Factory
class CoreModule {

    @Singleton
    fun clock(): ClockPort = ClockAdapter()

    @Singleton
    fun idGenerator(): IdGeneratorPort = IdGeneratorAdapter()

    @Singleton
    fun dataSource(): DataSource {
        val config = DatabaseConfiguration.fromEnv()
        val dataSource = HikariDataSource(
            HikariConfig().apply {
                jdbcUrl = config.url
                maximumPoolSize = 10
                username = config.user
                password = config.password
            },
        )
        Flyway.configure().dataSource(dataSource).load().migrate()
        return dataSource
    }

    @Singleton
    fun dslContext(dataSource: DataSource): DSLContext = DSL.using(dataSource, SQLDialect.POSTGRES)
}
