package com.bed.cordato.core.main

import javax.sql.DataSource

import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource

import org.flywaydb.core.Flyway

import org.jooq.DSLContext
import org.jooq.SQLDialect
import org.jooq.impl.DSL

import org.koin.dsl.module

import com.bed.cordato.core.application.ports.ClockPort
import com.bed.cordato.core.application.ports.IdGeneratorPort
import com.bed.cordato.core.infrastructure.adapters.ClockAdapter
import com.bed.cordato.core.infrastructure.adapters.IdGeneratorAdapter
import com.bed.cordato.core.infrastructure.persistence.configurations.DatabaseConfiguration

/**
 * Core's DI module — the shared kernel every bounded context inherits: determinism ports
 * (clock, id generation) and the shared persistence wiring. Lives in core's own `main`
 * subpackage; the root `com.bed.cordato.main.Main` aggregates it with each context's module.
 * `domain` and `application` never import Koin — only this `main` layer wires.
 *
 * A pooled [DataSource] and a single [DSLContext] are the only things a feature's repositories
 * depend on — jOOQ/JDBC never leak past infrastructure. Flyway migrations (the schema source of
 * truth) run when the pool is first built, so the datasource is only ever handed out against an
 * up-to-date schema. Single-instance deploys today; a multi-instance migration gate is deferred
 * (see design.md risks).
 */
val coreModule = module {
    single<ClockPort> { ClockAdapter() }
    single<IdGeneratorPort> { IdGeneratorAdapter() }

    single<DataSource> {
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
        dataSource
    }

    single<DSLContext> { DSL.using(get<DataSource>(), SQLDialect.POSTGRES) }
}
