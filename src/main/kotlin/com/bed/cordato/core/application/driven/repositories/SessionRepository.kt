package com.bed.cordato.core.application.driven.repositories

import java.time.Instant

import com.bed.cordato.core.domain.entities.SessionEntity

/**
 * Driven port for session persistence — core's first repository. [open] creates and persists a
 * session at sign-in; [findActiveByToken] resolves the *live* session a token points at, for the
 * edge guard to consume. Implemented in core/infrastructure.
 */
interface SessionRepository {

    /**
     * Revokes the single session identified by [sessionId] — the counterpart to [revokeAllForPersonExcept],
     * scoped by session id alone (no `personId` needed). Revocation is **server-authoritative**: a revoked
     * session stops being resolved by [findActiveByToken] immediately, collapsing into the same absent result
     * an unknown token yields. "Nothing to revoke" (an unknown or already-revoked [sessionId]) is a valid
     * result — returns `false`, never an error.
     *
     * @return `true` when a live session was revoked; `false` when there was none to revoke.
     */
    fun revoke(sessionId: String): Boolean

    /**
     * Revokes **every** live session of the person [personId], with no exclusion — distinct from
     * [revokeAllForPersonExcept], which spares one. Used by account deletion, where there is no session left
     * to spare because the account itself stops existing. Revocation is **server-authoritative**: a revoked
     * session stops being resolved by [findActiveByToken] immediately. "Nothing to revoke" (the person has no
     * live session) is a valid result, never an error.
     */
    fun revokeAllForPerson(personId: String)

    /**
     * Persists [session].
     *
     * @return `true` when the row was inserted; `false` when it could not be (e.g. a token-hash
     *   collision — practically impossible for a `SecureRandom` token). A `false` result never
     *   leaks a datastore exception.
     */
    fun open(session: SessionEntity): Boolean

    /**
     * Resolves the live session a token points at, or `null` when there is none. Returns a session
     * only when the hash of the presented [token] matches a stored `hashToken` **and** that session
     * has not expired as of [now]; an unknown token, an expired session, and (later) a revoked one
     * all collapse to the same absent result — never an exception — so the edge treats missing,
     * invalid and expired tokens indistinguishably.
     */
    fun findActiveByToken(token: String, now: Instant): SessionEntity?

    /**
     * Revokes every live session of the person [personId] **except** the one identified by [sessionId] (the
     * caller's current session, spared). Revocation is **server-authoritative**: a revoked session stops being
     * resolved by [findActiveByToken] immediately, collapsing into the same absent result an unknown token
     * yields. The spared session is left intact, and "nothing to revoke" (the person has no other live
     * session) is a valid result — returns `0`, never an error.
     *
     * @return the number of sessions revoked (`0` when there were no other live sessions to revoke).
     */
    fun revokeAllForPersonExcept(personId: String, sessionId: String): Int

}
