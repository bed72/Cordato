package com.bed.cordato.features.identity.application.driving.commands

/**
 * Input to the "update own name" operation: the [personId] the edge guard already resolved from a live
 * session, and the [name] as it arrived on the wire (raw — the use case builds the `NameValueObject` and is
 * the authority on the invariant). The use case never re-reads the token or the session; the driving-side
 * answer to "who is calling" was settled by the filter, and the command carries only its result.
 */
data class UpdateNameCommand(
    val personId: String,
    val name: String,
)
