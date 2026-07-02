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
