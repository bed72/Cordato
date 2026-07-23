package com.bed.cordato.features.identity.application.driving.commands

/**
 * Input to the `SignOut` operation: the [sessionId] the edge guard already resolved from the live session
 * that authenticated this exact request. No `personId` is carried — revoking by session id alone is
 * sufficient, and the guard already established that this session belongs to the caller.
 */
data class SignOutCommand(
    val sessionId: String,
)
