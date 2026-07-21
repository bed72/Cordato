package com.bed.cordato

import kotlin.test.Test

import com.lemonappdev.konsist.api.Konsist
import com.lemonappdev.konsist.api.verify.assertFalse

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
    fun `domain and application never import a concrete logging library`() {
        production
            .files
            .filter { it.hasPackage("..domain..") || it.hasPackage("..application..") }
            .assertFalse { file ->
                file.hasImport { it.hasNameStartingWith("org.slf4j.") }
            }
    }

    @Test
    fun `domain and application never import a DI-framework symbol`() {
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
