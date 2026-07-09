package com.bed.cordato.features.identity.infrastructure.http.mappers.requests

import com.bed.cordato.features.identity.application.driving.commands.UpdateEmailCommand

import com.bed.cordato.features.identity.infrastructure.http.requests.UpdateEmailRequest

/**
 * Builds the application's [UpdateEmailCommand] from the [UpdateEmailRequest] body and the authenticated
 * actor's `personId`, as an `internal` extension so the call site reads `request.toCommand(actor.personId)`.
 * It carries the raw e-mail and password across unchanged: the e-mail invariant is the use case's (value
 * object's) authority, and the password is verified there — never this mapper's concern. The identity comes
 * from the actor the edge guard resolved, never from the body — the route can only edit the caller's own
 * e-mail.
 */
internal fun UpdateEmailRequest.toCommand(personId: String): UpdateEmailCommand = UpdateEmailCommand(
    personId = personId,
    email = email,
    password = password,
)
