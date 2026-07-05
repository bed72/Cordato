package com.bed.cordato.main

import javax.sql.DataSource

import io.micronaut.context.ApplicationContext
import io.micronaut.runtime.server.EmbeddedServer

/**
 * Composition root / entry point. Starts a Micronaut `ApplicationContext`, which discovers every
 * package's `@Factory` wiring (core's shared kernel plus each bounded context) into one object
 * graph, then eagerly resolves the [DataSource] so Flyway migrations run on startup — failing fast
 * if the database is unreachable or a migration is broken. Micronaut singletons are lazy, so this
 * explicit resolve is what forces the migration side effect at boot rather than on first use.
 *
 * Migrations run *before* the HTTP server opens its port, so the service never accepts a request
 * against an unmigrated schema. The [EmbeddedServer] (Netty) is resolved and started explicitly —
 * `ApplicationContext.run()` starts the bean context but not the server — and its non-daemon
 * threads keep the process alive. Launch with `./gradlew run`; it needs a reachable PostgreSQL:
 * `make db-up` first.
 */
fun main() {
    val context = ApplicationContext.run()

    // Realizing the DataSource runs the Flyway migrations against the configured database.
    context.getBean(DataSource::class.java)

    val server = context.getBean(EmbeddedServer::class.java).start()

    println("Cordato started on ${server.uri} — database migrated, modules wired, HTTP serving.")
}
