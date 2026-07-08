package com.bed.cordato.features.identity.application.commands

/**
 * Input to the `Me` operation: the [personId] the edge guard already resolved from a live session. The
 * use case never re-reads the token or the session — the driving-side answer to "who is calling" was
 * settled by the filter, and the command carries only its result.
 */
data class MeCommand(
    val personId: String,
)
