package com.bed.cordato

import kotlin.test.Test

import com.lemonappdev.konsist.api.Konsist
import com.lemonappdev.konsist.api.verify.assertFalse

/**
 * Enforces, at build time, the two dependency-direction rules documented in
 * CLAUDE.md and README.md:
 *
 *   1. Inside a module, dependencies point inward: infrastructure -> application -> domain.
 *   2. Only `couple` may depend on sibling bounded contexts; budget/expense/identity stay isolated.
 *
 * These are written as declarative import assertions rather than Konsist's
 * `assertArchitecture` layer DSL on purpose. `assertArchitecture` calls
 * `checkLayersWithoutFiles` and throws `KoPreconditionFailedException` the
 * moment *any* declared layer contains zero files — which is the case now (no
 * feature code exists yet) and stays the case during incremental development
 * (e.g. adding a `domain` entity before its `infrastructure`). `assertFalse`
 * defaults to `strict = false`, so it passes vacuously on an empty/partial
 * scope and only starts failing once a file that actually violates the rule is
 * added.
 */
class ArchitectureTest {

    private val production = Konsist.scopeFromProduction()

    @Test
    fun `domain never depends on application or infrastructure`() {
        production
            .files
            .filter { it.hasPackage("..domain..") }
            .assertFalse { file ->
                file.hasImport {
                    it.hasNameContaining(".application.") || it.hasNameContaining(".infrastructure.")
                }
            }
    }

    @Test
    fun `application never depends on infrastructure`() {
        production
            .files
            .filter { it.hasPackage("..application..") }
            .assertFalse { file ->
                file.hasImport { it.hasNameContaining(".infrastructure.") }
            }
    }

    @Test
    fun `domain and application never import a persistence library`() {
        // The layer table keeps jOOQ/JDBC/Hikari/Flyway confined to infrastructure. The
        // ".infrastructure." rules above don't catch a direct `org.jooq.*` import into an
        // inner layer, so this guards that leak explicitly.
        val persistenceLibraries = listOf("org.jooq", "org.postgresql", "com.zaxxer.hikari", "org.flywaydb")

        production
            .files
            .filter { it.hasPackage("..domain..") || it.hasPackage("..application..") }
            .assertFalse { file ->
                file.hasImport { import ->
                    persistenceLibraries.any { import.hasNameStartingWith("$it.") }
                }
            }
    }

    @Test
    fun `domain and application never import a DI-framework symbol`() {
        // DI wiring is confined to each package's `main/` subpackage (and adapters in
        // `infrastructure/`); the pure layers stay framework-agnostic. This bars both the previous
        // Koin API and Micronaut's DI annotations (`io.micronaut.context.annotation.*` — e.g.
        // @Factory/@Bean — and the `jakarta.inject.*` set — @Singleton/@Inject). Only
        // `infrastructure/` and `main/` may reference these; the package filter below excludes them.
        val diLibraries = listOf("org.koin", "io.micronaut.context.annotation", "jakarta.inject")

        production
            .files
            .filter { it.hasPackage("..domain..") || it.hasPackage("..application..") }
            .assertFalse { file ->
                file.hasImport { import ->
                    diLibraries.any { import.hasNameStartingWith("$it.") }
                }
            }
    }

    @Test
    fun `budget, expense and identity never depend on a sibling context`() {
        val siblings = mapOf(
            "budget" to listOf("expense", "identity", "couple"),
            "expense" to listOf("budget", "identity", "couple"),
            "identity" to listOf("budget", "expense", "couple"),
        )

        production
            .files
            .assertFalse { file ->
                siblings.any { (context, forbidden) ->
                    file.hasPackage("com.bed.cordato.features.$context..") &&
                        file.hasImport { import ->
                            forbidden.any { import.hasNameStartingWith("com.bed.cordato.features.$it.") }
                        }
                }
            }
    }
}
