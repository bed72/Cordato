package com.bed.cordato.core.factories

import java.time.Instant

import com.bed.cordato.core.domain.entities.SessionEntity
import com.bed.cordato.core.application.driven.repositories.SessionRepository

const val LIVE_TOKEN = "live-token"
const val SESSION_PERSON_ID = "person-1"
const val LIVE_SESSION_ID = "session-1"

/**
 * Deterministic [SessionRepository] fake for the edge-auth guard: only [LIVE_TOKEN] resolves to a live
 * session ([LIVE_SESSION_ID], owned by [SESSION_PERSON_ID]); every other token collapses to `null`, standing
 * in for the absent/expired/revoked cases the real repository already folds together. Lets the guard be
 * exercised end-to-end without a `DataSource`.
 *
 * [revokeAllForPersonExcept] records its last call so a test can assert which person/session the use case
 * asked to spare; it mirrors the production "nothing to revoke is 0" contract by returning `0`.
 */
class FakeSessionRepository : SessionRepository {
    var revokedForPerson: String? = null
        private set
    var sparedSessionId: String? = null
        private set

    override fun open(session: SessionEntity): Boolean = true

    override fun findActiveByToken(token: String, now: Instant): SessionEntity? =
        if (token == LIVE_TOKEN) {
            session(id = LIVE_SESSION_ID, personId = SESSION_PERSON_ID, createdAt = now)
        } else {
            null
        }

    override fun revokeAllForPersonExcept(personId: String, sessionId: String): Int {
        revokedForPerson = personId
        sparedSessionId = sessionId
        return 0
    }
}
