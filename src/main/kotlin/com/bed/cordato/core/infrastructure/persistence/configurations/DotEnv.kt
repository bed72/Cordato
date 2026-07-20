package com.bed.cordato.core.infrastructure.persistence.configurations

import java.io.File

/**
 * The `.env`-file fallback every process configuration (Postgres, Valkey, ...) resolves through —
 * Micronaut has no built-in `.env` support, and `@Value` only ever sees real environment variables, so a
 * config read that way (like the cache-valkey kernel's) silently misses whatever only lives in `.env`.
 * [resolve] overlays a local `.env` (if present) with the real process environment, which always wins.
 */
object DotEnv {
    fun resolve(file: File = File(".env")): Map<String, String> = read(file) + System.getenv()

    private fun read(file: File): Map<String, String> {
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
