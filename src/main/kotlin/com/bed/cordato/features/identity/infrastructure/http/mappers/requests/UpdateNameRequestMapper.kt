package com.bed.cordato.features.identity.infrastructure.http.mappers.requests

import com.bed.cordato.features.identity.application.commands.UpdateNameCommand

import com.bed.cordato.features.identity.infrastructure.http.requests.UpdateNameRequest

/**
 * Builds the application's [UpdateNameCommand] from the [UpdateNameRequest] body and the authenticated
 * actor's `personId`, as an `internal` extension so the call site reads `request.toCommand(actor.personId)`.
 * It carries the raw name across unchanged: the invariant is the use case's (value object's) authority,
 * never this mapper's. The identity comes from the actor the edge guard resolved, never from the body — the
 * route can only edit the caller's own name.
 */
internal fun UpdateNameRequest.toCommand(personId: String): UpdateNameCommand = UpdateNameCommand(
    personId = personId,
    name = name,
)
