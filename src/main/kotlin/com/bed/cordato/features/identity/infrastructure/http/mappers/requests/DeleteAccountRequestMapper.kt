package com.bed.cordato.features.identity.infrastructure.http.mappers.requests

import com.bed.cordato.features.identity.infrastructure.http.requests.DeleteAccountRequest
import com.bed.cordato.features.identity.application.driving.commands.DeleteAccountCommand

/**
 * Builds the application's [DeleteAccountCommand] from the [DeleteAccountRequest] body and the authenticated
 * actor's `personId`, as an `internal` extension so the call site reads `request.toCommand(actor.personId)`.
 * The identity comes from the actor the edge guard resolved, never from the body — the route can only
 * delete the caller's own account.
 */
internal fun DeleteAccountRequest.toCommand(personId: String): DeleteAccountCommand =
    DeleteAccountCommand(personId = personId, password = password)
