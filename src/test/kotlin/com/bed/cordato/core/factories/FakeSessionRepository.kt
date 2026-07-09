package com.bed.cordato.core.factories

import java.time.Instant

import com.bed.cordato.core.domain.entities.SessionEntity
import com.bed.cordato.core.application.driven.repositories.SessionRepository

const val LIVE_TOKEN = "live-token"
const val SESSION_PERSON_ID = "person-1"

/**
 * Deterministic [SessionRepository] fake for the edge-auth guard: only [LIVE_TOKEN] resolves to a live
 * session (owned by [SESSION_PERSON_ID]); every other token collapses to `null`, standing in for the
 * absent/expired/revoked cases the real repository already folds together. Lets the guard be exercised
 * end-to-end without a `DataSource`.
 */
class FakeSessionRepository : SessionRepository {
    override fun open(session: SessionEntity): Boolean = true

    override fun findActiveByToken(token: String, now: Instant): SessionEntity? =
        if (token == LIVE_TOKEN) session(personId = SESSION_PERSON_ID, createdAt = now) else null
}
