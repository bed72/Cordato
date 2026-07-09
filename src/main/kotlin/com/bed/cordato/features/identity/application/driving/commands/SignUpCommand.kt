package com.bed.cordato.features.identity.application.driving.commands

/**
 * Raw signup input as it arrives from the outside world. The use case is responsible
 * for turning these strings into validated value objects — validation is behavior,
 * not the caller's job.
 */
data class SignUpCommand(
    val name: String,
    val email: String,
    val password: String,
)
