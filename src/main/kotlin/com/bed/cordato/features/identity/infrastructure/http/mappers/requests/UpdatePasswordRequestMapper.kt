package com.bed.cordato.features.identity.infrastructure.http.mappers.requests

import com.bed.cordato.features.identity.infrastructure.http.requests.UpdatePasswordRequest
import com.bed.cordato.features.identity.application.driving.commands.UpdatePasswordCommand

/**
 * Builds the application's [UpdatePasswordCommand] from the [UpdatePasswordRequest] body and the authenticated
 * actor's `personId`/`sessionId`, as an `internal` extension so the call site reads
 * `request.toCommand(actor.personId, actor.sessionId)`. It carries the raw current/new passwords across
 * unchanged: the new-password policy is the use case's (value object's) authority, and the current password is
 * verified there — never this mapper's concern. The identity and session come from the actor the edge guard
 * resolved, never from the body — the route can only rotate the caller's own password, sparing the caller's
 * own session.
 */
internal fun UpdatePasswordRequest.toCommand(personId: String, sessionId: String): UpdatePasswordCommand =
    UpdatePasswordCommand(
        personId = personId,
        sessionId = sessionId,
        newPassword = newPassword,
        currentPassword = currentPassword,
    )
