package com.bed.cordato.features.identity.infrastructure.http.mappers

import com.bed.cordato.features.identity.application.commands.SignUpCommand

import com.bed.cordato.features.identity.infrastructure.http.requests.SignUpRequest

/**
 * Turns the HTTP [SignUpRequest] into the application's [SignUpCommand] — a straight field copy,
 * as an `internal` extension so the call site reads `request.toCommand()`. It carries the raw
 * strings across unchanged: validation is the use case's behavior, never this mapper's.
 */
internal fun SignUpRequest.toCommand(): SignUpCommand = SignUpCommand(
    name = name,
    email = email,
    password = password,
)
