package com.bed.cordato.features.identity.infrastructure.http.controllers

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Get
import io.micronaut.http.annotation.Body
import io.micronaut.http.annotation.Patch
import io.micronaut.http.annotation.Status
import io.micronaut.http.annotation.Controller

import io.micronaut.validation.Validated

import jakarta.validation.Valid

import com.bed.cordato.core.application.driven.ports.MessagePort

import com.bed.cordato.features.identity.application.driving.results.MeResult
import com.bed.cordato.features.identity.application.driving.commands.MeCommand
import com.bed.cordato.features.identity.application.driving.use_cases.MeUseCase
import com.bed.cordato.features.identity.application.driving.results.UpdateNameResult
import com.bed.cordato.features.identity.application.driving.use_cases.UpdateNameUseCase
import com.bed.cordato.features.identity.application.driving.results.UpdateEmailResult
import com.bed.cordato.features.identity.application.driving.use_cases.UpdateEmailUseCase

import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor
import com.bed.cordato.core.infrastructure.http.authentication.annotations.Authenticated

import com.bed.cordato.features.identity.infrastructure.http.mappers.errors.toResponse
import com.bed.cordato.features.identity.infrastructure.http.requests.UpdateNameRequest
import com.bed.cordato.features.identity.infrastructure.http.requests.UpdateEmailRequest
import com.bed.cordato.features.identity.infrastructure.http.mappers.requests.toCommand
import com.bed.cordato.features.identity.infrastructure.http.mappers.responses.toResponse
import com.bed.cordato.features.identity.infrastructure.http.controllers.docs.PersonControllerDoc

/**
 * Identity's driving (primary/inbound) HTTP adapter for operations on the already-authenticated person —
 * kept apart from the [AuthenticationController], which owns only the open session-*minting* flows. Today it
 * exposes `GET /persons/me` (read), `PATCH /persons/me/name` (edit the own name) and `PATCH /persons/me/email`
 * (change the own e-mail, confirming the current password); future `DELETE` slots in here. The two edits are
 * symmetric single-field sub-resources (`/me/name`, `/me/email`), not one ambiguous multi-field `PATCH /me`.
 *
 * `@Authenticated` lives **on the method**, not the class: declaring it is what makes the edge guard require
 * a live session before the handler runs — a missing/invalid/expired token is refused with the neutral `401`
 * *before* the handler, so the use cases are never reached without a resolved caller. Marking per-method
 * keeps the granularity honest for routes that may guard differently. The [AuthenticatedActor] is injected
 * by core's binder from the attribute the filter wrote; each handler only turns its `personId` into a command.
 *
 * `@Validated` + `@Valid` run the [UpdateNameRequest]'s Bean Validation constraints first: a violation is
 * thrown as a `ConstraintViolationException` (turned into a `400` by core's shared handler) before the use
 * case is reached. Only the caller's own name can change — the identity comes from the actor, never the body.
 *
 * Like [AuthenticationController], this is a discovered `@Controller` (there is no factory way to declare a
 * route); it depends only on the pure use-case beans and the [MessagePort]. It branches over each sealed
 * result: `Success` → `200` with the public person view, `Failure` → [toResponse] (`InvalidName` → `422`; an
 * orphaned session → the neutral `401`, indistinguishable from a missing one). The OpenAPI documentation
 * lives on the implemented [PersonControllerDoc].
 */
@Validated
@Controller("/persons")
class PersonController(
    private val messages: MessagePort,
    private val meUseCase: MeUseCase,
    private val updateNameUseCase: UpdateNameUseCase,
    private val updateEmailUseCase: UpdateEmailUseCase,
) : PersonControllerDoc {

    @Authenticated
    @Get("/me")
    @Status(HttpStatus.OK)
    override fun me(actor: AuthenticatedActor): HttpResponse<*> =
        when (val data = meUseCase(MeCommand(actor.personId))) {
            is MeResult.Failure -> data.error.toResponse(messages)
            is MeResult.Success -> HttpResponse.ok(data.person.toResponse())
        }

    @Authenticated
    @Patch("/me/name")
    @Status(HttpStatus.OK)
    override fun updateName(actor: AuthenticatedActor, @Body @Valid request: UpdateNameRequest): HttpResponse<*> =
        when (val data = updateNameUseCase(request.toCommand(actor.personId))) {
            is UpdateNameResult.Failure -> data.error.toResponse(messages)
            is UpdateNameResult.Success -> HttpResponse.ok(data.person.toResponse())
        }

    @Authenticated
    @Patch("/me/email")
    @Status(HttpStatus.OK)
    override fun updateEmail(actor: AuthenticatedActor, @Body @Valid request: UpdateEmailRequest): HttpResponse<*> =
        when (val data = updateEmailUseCase(request.toCommand(actor.personId))) {
            is UpdateEmailResult.Failure -> data.error.toResponse(messages)
            is UpdateEmailResult.Success -> HttpResponse.ok(data.person.toResponse())
        }
}
