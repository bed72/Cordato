package com.bed.cordato.core.infrastructure.persistence.configurations

import kotlin.test.Test
import kotlin.test.assertEquals

class DatabaseConfigurationTest {

    @Test
    fun `falls back to local defaults when nothing is set`() {
        val config = DatabaseConfiguration.fromEnv(emptyMap())

        assertEquals("jdbc:postgresql://localhost:5432/cordato", config.url)
        assertEquals("cordato", config.user)
        assertEquals("cordato", config.password)
    }

    @Test
    fun `builds the JDBC url from the discrete POSTGRES_ parts`() {
        val config = DatabaseConfiguration.fromEnv(
            mapOf(
                "POSTGRES_HOST" to "db.internal",
                "POSTGRES_PORT" to "6543",
                "POSTGRES_DB" to "prod",
                "POSTGRES_USER" to "app",
                "POSTGRES_PASSWORD" to "s3cret",
            ),
        )

        assertEquals("jdbc:postgresql://db.internal:6543/prod", config.url)
        assertEquals("app", config.user)
        assertEquals("s3cret", config.password)
    }
}
