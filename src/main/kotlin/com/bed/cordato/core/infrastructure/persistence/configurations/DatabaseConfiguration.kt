package com.bed.cordato.core.infrastructure.persistence.configurations

/**
 * Datastore connection settings (12-factor — no secrets in source). Values come from the process
 * environment, with an optional git-ignored `.env` file filling in whatever the environment does
 * not set ([DotEnv]), so credentials live outside the codebase in both dev and prod. The JDBC URL is
 * derived from the same discrete `POSTGRES_*` variables `compose.yml` uses, keeping a single source of
 * truth. Defaults match `.env.example`, so local run needs no extra configuration.
 */
data class DatabaseConfiguration(
    val url: String,
    val user: String,
    val password: String,
) {
    companion object {
        fun fromEnv(env: Map<String, String> = DotEnv.resolve()): DatabaseConfiguration {
            val port = env["POSTGRES_PORT"] ?: "5432"
            val host = env["POSTGRES_HOST"] ?: "localhost"
            val database = env["POSTGRES_DB"] ?: "cordato"

            return DatabaseConfiguration(
                user = env["POSTGRES_USER"] ?: "cordato",
                url = "jdbc:postgresql://$host:$port/$database",
                password = env["POSTGRES_PASSWORD"] ?: "cordato",
            )
        }
    }
}
