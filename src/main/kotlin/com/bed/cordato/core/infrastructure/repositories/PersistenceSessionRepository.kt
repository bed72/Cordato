package com.bed.cordato.core.infrastructure.repositories

import java.time.Instant
import java.time.ZoneOffset

import org.jooq.DSLContext
import org.jooq.exception.DataAccessException

import com.bed.cordato.core.domain.entities.SessionEntity

import com.bed.cordato.core.application.ports.TokenizerPort
import com.bed.cordato.core.application.repositories.SessionRepository

import com.bed.cordato.core.infrastructure.repositories.mappers.toEntity
import com.bed.cordato.core.infrastructure.repositories.mappers.toRecord
import com.bed.cordato.core.infrastructure.persistence.models.Tables.SESSION

/**
 * Durable [SessionRepository] on PostgreSQL via jOOQ. [open] inserts the session; a hash-token
 * collision (the `session_hash_token_key` UNIQUE constraint) maps to `false` rather than crossing a
 * datastore exception into application — practically unreachable for a `SecureRandom` token, but the
 * port's `Boolean` carries the outcome all the same.
 *
 * [findActiveByToken] hashes the presented token through the [TokenizerPort] and matches the stored
 * `hash_token` — the plaintext never touches the query — filtering to sessions still live at `now`,
 * so an unknown token, an expired session, and a missing one are indistinguishable absences.
 */
class PersistenceSessionRepository(
    private val dsl: DSLContext,
    private val tokenizer: TokenizerPort,
) : SessionRepository {

    override fun open(session: SessionEntity): Boolean =
        try {
            dsl.insertInto(SESSION)
                .set(session.toRecord())
                .execute()
            true
        } catch (exception: DataAccessException) {
            if (exception.sqlState() == UNIQUE_VIOLATION) false else throw exception
        }

    override fun findActiveByToken(token: String, now: Instant): SessionEntity? =
        dsl.selectFrom(SESSION)
            .where(SESSION.HASH_TOKEN.eq(tokenizer.hash(token)))
            .and(SESSION.EXPIRES_AT.gt(now.atOffset(ZoneOffset.UTC)))
            .fetchOne()
            ?.toEntity()

    private companion object {
        const val UNIQUE_VIOLATION = "23505"
    }
}
