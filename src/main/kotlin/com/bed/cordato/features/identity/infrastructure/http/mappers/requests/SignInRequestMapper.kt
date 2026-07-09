package com.bed.cordato.features.identity.infrastructure.http.mappers.requests

import com.bed.cordato.features.identity.application.driving.commands.SignInCommand

import com.bed.cordato.features.identity.infrastructure.http.requests.SignInRequest

/**
 * Turns the HTTP [SignInRequest] into the application's [SignInCommand] — a straight field copy, as
 * an `internal` extension so the call site reads `request.toCommand()`. It carries the raw strings
 * across unchanged: validation is the use case's behavior, never this mapper's.
 */
internal fun SignInRequest.toCommand(): SignInCommand = SignInCommand(
    email = email,
    password = password,
)
