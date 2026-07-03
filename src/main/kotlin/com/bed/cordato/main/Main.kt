package com.bed.cordato.main

import javax.sql.DataSource

import org.koin.core.context.startKoin

import com.bed.cordato.core.main.coreModule
import com.bed.cordato.features.identity.main.identityModule

/**
 * Composition root / entry point. Starts Koin with the shared core wiring plus each bounded
 * context's module, then eagerly resolves the [DataSource] so Flyway migrations run
 * on startup — failing fast if the database is unreachable or a migration is broken.
 *
 * No `application` Gradle plugin is configured (see CLAUDE.md), so this is launched from the
 * IDE. It needs a reachable PostgreSQL: `make db-up` first.
 */
fun main() {
    val application = startKoin {
        modules(coreModule, identityModule)
    }

    // Realizing the DataSource runs the Flyway migrations against the configured database.
    application.koin.get<DataSource>()

    println("Cordato started — database migrated and modules wired.")
}
