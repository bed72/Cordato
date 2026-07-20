package com.bed.cordato.core.infrastructure.persistence.configurations

/**
 * Valkey (distributed cache) connection settings — same 12-factor stance as [DatabaseConfiguration]:
 * values come from the process environment, with [DotEnv] filling in whatever only lives in the local
 * `.env`. `compose.yml` maps the same `VALKEY_HOST`/`VALKEY_PORT` variables onto the container's published
 * port, keeping a single source of truth. Defaults match `.env.example`.
 */
data class ValkeyConfiguration(
    val host: String,
    val port: Int,
) {
    companion object {
        fun fromEnv(env: Map<String, String> = DotEnv.resolve()): ValkeyConfiguration = ValkeyConfiguration(
            host = env["VALKEY_HOST"] ?: "localhost",
            port = env["VALKEY_PORT"]?.toIntOrNull() ?: 6379,
        )
    }
}
