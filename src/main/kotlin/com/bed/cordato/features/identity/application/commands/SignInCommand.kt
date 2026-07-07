package com.bed.cordato.features.identity.application.commands

/**
 * Raw login input as it arrives from the outside world. The use case turns [email] into a value
 * object and verifies [password] against the stored hash — the command carries only the raw
 * strings, validation is the use case's behavior, not the caller's.
 */
data class SignInCommand(
    val email: String,
    val password: String,
)
