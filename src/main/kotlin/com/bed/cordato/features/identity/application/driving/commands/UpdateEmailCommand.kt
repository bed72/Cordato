package com.bed.cordato.features.identity.application.driving.commands

/**
 * Input to the "update own e-mail" operation: the [personId] the edge guard already resolved from a live
 * session, the [email] as it arrived on the wire (raw — the use case builds the `EmailValueObject` and is the
 * authority on the invariant), and the current [password] as plaintext, for step-up confirmation. The use
 * case never re-reads the token or the session; the driving-side answer to "who is calling" was settled by
 * the filter, and the command carries only its result.
 */
data class UpdateEmailCommand(
    val personId: String,
    val email: String,
    val password: String,
)
