package com.bed.cordato.core.main

import org.jooq.impl.DSL
import org.jooq.SQLDialect
import org.jooq.DSLContext

import javax.sql.DataSource
import org.flywaydb.core.Flyway
import jakarta.inject.Singleton

import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource

import io.micronaut.context.MessageSource
import io.micronaut.context.annotation.Factory
import io.micronaut.context.LocalizedMessageSource
import io.micronaut.context.i18n.ResourceBundleMessageSource

import com.bed.cordato.core.application.ports.ClockPort
import com.bed.cordato.core.application.ports.MessagePort
import com.bed.cordato.core.application.ports.TokenizerPort
import com.bed.cordato.core.application.ports.IdGeneratorPort
import com.bed.cordato.core.application.repositories.SessionRepository

import com.bed.cordato.core.infrastructure.adapters.ClockAdapter
import com.bed.cordato.core.infrastructure.adapters.MessageAdapter
import com.bed.cordato.core.infrastructure.adapters.TokenizerAdapter
import com.bed.cordato.core.infrastructure.adapters.IdGeneratorAdapter
import com.bed.cordato.core.infrastructure.repositories.PersistenceSessionRepository
import com.bed.cordato.core.infrastructure.persistence.configurations.DatabaseConfiguration

/**
 * Core's DI factory — the shared kernel every bounded context inherits: determinism ports
 * (clock, id generation) and the shared persistence wiring. Lives in core's own `main`
 * subpackage; the root `com.bed.cordato.main.Main` starts one `ApplicationContext` that
 * discovers this factory alongside each context's. `domain` and `application` never import
 * Micronaut — only this `main` layer wires. The pure ports/adapters carry no annotations,
 * so each `@Singleton` method here is the single explicit place they are constructed.
 *
 * A pooled [DataSource] and a single [DSLContext] are the only things a feature's repositories
 * depend on — jOOQ/JDBC never leak past infrastructure. Flyway migrations (the schema source of
 * truth) run when the pool is first built, so the datasource is only ever handed out against an
 * up-to-date schema. Single-instance deploys today; a multi-instance migration gate is deferred
 * (see design.md risks).
 */
@Factory
class CoreFactory {

    @Singleton
    fun clock(): ClockPort = ClockAdapter()

    @Singleton
    fun idGenerator(): IdGeneratorPort = IdGeneratorAdapter()

    /**
     * The shared message bundle every HTTP response text is resolved from — the i18n counterpart of
     * core's cross-cutting error contract. `i18n.messages` maps to `i18n/messages.properties` on the
     * classpath (pt-BR default); a `LocalizedMessageSource` (request-scoped, `Accept-Language`-aware)
     * is layered on top of this bean by micronaut-http-server, and the Bean Validation interpolator
     * resolves its `{key}` message templates against it too. Kept here rather than in a dedicated
     * factory to honour the "one `@Factory` per package" wiring convention.
     */
    @Singleton
    fun messageSource(): MessageSource = ResourceBundleMessageSource("i18n.messages")

    /**
     * Core's own [MessagePort] over Micronaut's request-scoped [LocalizedMessageSource] — the single
     * place the framework i18n type is named, so every HTTP call site downstream depends on our contract.
     * The injected source is request-aware (proxied per `Accept-Language`), so a plain singleton suffices.
     */
    @Singleton
    fun messageResolver(messages: LocalizedMessageSource): MessagePort = MessageAdapter(messages)

    @Singleton
    fun dslContext(dataSource: DataSource): DSLContext = DSL.using(dataSource, SQLDialect.POSTGRES)

    @Singleton
    fun tokenizer(): TokenizerPort = TokenizerAdapter()

    // Durable PostgreSQL adapter; the DSLContext comes from this same factory. The tokenizer hashes a
    // presented token before it ever reaches a query, so the repository never sees a plaintext column.
    @Singleton
    fun sessionRepository(dslContext: DSLContext, tokenizer: TokenizerPort): SessionRepository =
        PersistenceSessionRepository(dslContext, tokenizer)

    @Singleton
    fun dataSource(): DataSource {
        val config = DatabaseConfiguration.fromEnv()
        val dataSource = HikariDataSource(
            HikariConfig().apply {
                jdbcUrl = config.url
                maximumPoolSize = 10
                username = config.user
                password = config.password
            },
        )
        Flyway.configure().dataSource(dataSource).load().migrate()

        return dataSource
    }

}
