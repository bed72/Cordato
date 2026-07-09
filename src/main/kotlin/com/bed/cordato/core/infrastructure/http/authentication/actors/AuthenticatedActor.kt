package com.bed.cordato.core.infrastructure.http.authentication.actors

/**
 * The authenticated actor at the HTTP edge — the driving-side answer to "who is calling this route?": the
 * caller identity the filter resolves from a live session. Carries the [personId] **and** the current
 * [sessionId] — the latter needed for session-scoped operations (e.g. revoking the person's other sessions
 * while sparing the current one) — but **never** the token nor any other person data; anything richer is
 * fetched through a use case, never leaked at the edge.
 *
 * A plain `data class` (not a value class) so Micronaut's typed argument binding resolves it without the
 * value-class binding pitfall. [ATTRIBUTE] and [ATTRIBUTE_SESSION] are the request-attribute keys the person
 * id and session id travel under: the filter writes both after resolving a live session, the binder reads
 * them back — namespaced under the type they transport rather than as scattered top-level constants.
 */
data class AuthenticatedActor(val personId: String, val sessionId: String) {
    companion object {
        internal const val ATTRIBUTE = "cordato.authentication.personId"
        internal const val ATTRIBUTE_SESSION = "cordato.authentication.sessionId"
    }
}
