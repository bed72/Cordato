package com.bed.cordato.core.infrastructure.persistence.configurations

import java.io.File

/**
 * Datastore connection settings (12-factor — no secrets in source). Values come from the process
 * environment, with an optional git-ignored `.env` file filling in whatever the environment does
 * not set, so credentials live outside the codebase in both dev and prod. The JDBC URL is derived
 * from the same discrete `POSTGRES_*` variables `compose.yml` uses, keeping a single source of
 * truth. Defaults match `.env.example`, so local run needs no extra configuration.
 */
data class DatabaseConfiguration(
    val url: String,
    val user: String,
    val password: String,
) {
    companion object {
        fun fromEnv(env: Map<String, String> = environment()): DatabaseConfiguration {
            val host = env["POSTGRES_HOST"] ?: "localhost"
            val port = env["POSTGRES_PORT"] ?: "5432"
            val database = env["POSTGRES_DB"] ?: "cordato"

            return DatabaseConfiguration(
                url = "jdbc:postgresql://$host:$port/$database",
                user = env["POSTGRES_USER"] ?: "cordato",
                password = env["POSTGRES_PASSWORD"] ?: "cordato",
            )
        }

        /** Local `.env` values (if present) overlaid by real environment variables, which win. */
        private fun environment(): Map<String, String> = dotEnv() + System.getenv()

        private fun dotEnv(file: File = File(".env")): Map<String, String> {
            if (!file.exists()) return emptyMap()
            return file.readLines()
                .map(String::trim)
                .filter { it.isNotEmpty() && !it.startsWith("#") && '=' in it }
                .associate { line ->
                    val (key, value) = line.split("=", limit = 2)
                    key.trim() to value.trim().trim('"')
                }
        }
    }
}
