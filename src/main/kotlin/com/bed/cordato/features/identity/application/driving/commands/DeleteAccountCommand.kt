package com.bed.cordato.features.identity.application.driving.commands

/**
 * Input to the "delete own account" operation: the [personId] the edge guard already resolved from a live
 * session, and the current [password] as plaintext (for step-up confirmation). The use case never re-reads
 * the token or the session; the driving-side answer to "who is calling" was settled by the filter, and the
 * command carries only its result.
 */
data class DeleteAccountCommand(
    val personId: String,
    val password: String,
)
