package com.bed.cordato.features.identity.application.driving.commands

/**
 * Input to the "update own password" operation: the [personId] and [sessionId] the edge guard already
 * resolved from a live session, the current [currentPassword] as plaintext (for step-up confirmation), and
 * the [newPassword] as it arrived on the wire (raw — the use case builds the `PasswordValueObject` and is the
 * authority on the policy). The [sessionId] names the caller's current session, so the use case can revoke the
 * person's **other** sessions while sparing this one. The use case never re-reads the token or the session;
 * the driving-side answer to "who is calling" was settled by the filter, and the command carries only its
 * result.
 */
data class UpdatePasswordCommand(
    val personId: String,
    val sessionId: String,
    val newPassword: String,
    val currentPassword: String,
)
