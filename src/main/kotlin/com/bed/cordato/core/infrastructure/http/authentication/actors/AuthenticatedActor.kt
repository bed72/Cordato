package com.bed.cordato.core.infrastructure.http.authentication.actors

/**
 * The authenticated actor at the HTTP edge — the driving-side answer to "who is calling this route?": the
 * caller identity the filter resolves from a live session. Carries **only** the [personId] — never the
 * token nor any other person data; anything richer is fetched through a use case, never leaked at the edge.
 *
 * A plain `data class` (not a value class) so Micronaut's typed argument binding resolves it without the
 * value-class binding pitfall. [ATTRIBUTE] is the request-attribute key this actor's id travels under: the
 * filter writes it after resolving a live session, the binder reads it back — namespaced under the type it
 * transports rather than as a scattered top-level constant.
 */
data class AuthenticatedActor(val personId: String) {
    companion object {
        internal const val ATTRIBUTE = "cordato.authentication.personId"
    }
}
