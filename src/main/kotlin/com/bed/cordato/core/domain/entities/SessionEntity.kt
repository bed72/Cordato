package com.bed.cordato.core.domain.entities

import java.time.Instant
import java.time.Duration

/**
 * A session — core's first persisted aggregate and the anchor of every authenticated request.
 * A session is opened for a person at sign-in and stays *live* only until [expiresAt].
 *
 * Non-leak by construction: only [hashToken] (the SHA-256 of the opaque token) is ever held or
 * stored, never the plaintext token. The plaintext is handed to the client exactly once at
 * open time and is not recoverable from a session afterwards — resolving a session by token
 * compares hashes, it never reverses one. [personId] is the identity anchor the session belongs to.
 */
data class SessionEntity(
    val id: String,
    val personId: String,
    val hashToken: String,
    val expiresAt: Instant,
    val createdAt: Instant,
) {
    companion object {
        /**
         * How long a session stays live from the moment it is opened. Session lifetime is core's
         * policy (the session aggregate lives here), so the constant does too — a single ~1-day TTL
         * until revocation/refresh (out of scope) call for something richer.
         */
        val TTL: Duration = Duration.ofDays(1)
    }
}
