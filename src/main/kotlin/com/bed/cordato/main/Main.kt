package com.bed.cordato.main

import javax.sql.DataSource

import io.micronaut.context.ApplicationContext

/**
 * Composition root / entry point. Starts a Micronaut `ApplicationContext`, which discovers every
 * package's `@Factory` wiring (core's shared kernel plus each bounded context) into one object
 * graph, then eagerly resolves the [DataSource] so Flyway migrations run on startup — failing fast
 * if the database is unreachable or a migration is broken. Micronaut singletons are lazy, so this
 * explicit resolve is what forces the migration side effect at boot rather than on first use.
 *
 * No `application` Gradle plugin is configured (see CLAUDE.md), so this is launched from the
 * IDE. It needs a reachable PostgreSQL: `make db-up` first.
 */
fun main() {
    val context = ApplicationContext.run()

    // Realizing the DataSource runs the Flyway migrations against the configured database.
    context.getBean(DataSource::class.java)

    println("Cordato started — database migrated and modules wired.")
}
