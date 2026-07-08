package com.bed.cordato.features.identity.infrastructure.http.controllers

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Get
import io.micronaut.http.annotation.Status
import io.micronaut.http.annotation.Controller

import com.bed.cordato.core.application.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor
import com.bed.cordato.core.infrastructure.http.authentication.annotations.Authenticated

import com.bed.cordato.features.identity.application.results.MeResult
import com.bed.cordato.features.identity.application.commands.MeCommand
import com.bed.cordato.features.identity.application.use_cases.MeUseCase

import com.bed.cordato.features.identity.infrastructure.http.mappers.errors.toResponse
import com.bed.cordato.features.identity.infrastructure.http.mappers.responses.toResponse
import com.bed.cordato.features.identity.infrastructure.http.controllers.docs.PersonControllerDoc

/**
 * Identity's driving (primary/inbound) HTTP adapter for operations on the already-authenticated person —
 * kept apart from the [AuthenticationController], which owns only the open session-*minting* flows. Today it
 * exposes `GET /persons/me`; future `PATCH`/`DELETE` on the person slot in here.
 *
 * `@Authenticated` lives **on the method**, not the class: declaring it is what makes the edge guard require
 * a live session before `me()` runs — a missing/invalid/expired token is refused with the neutral `401`
 * *before* the handler, so the [MeUseCase] is never reached without a resolved caller. Marking per-method
 * keeps the granularity honest for future routes that may guard differently. The [AuthenticatedActor] is
 * injected by core's binder from the attribute the filter wrote; the handler only turns its `personId` into
 * a [MeCommand].
 *
 * Like [AuthenticationController], this is a discovered `@Controller` (there is no factory way to declare a
 * route); it depends only on the pure [MeUseCase] bean and the [MessagePort]. It branches over the sealed
 * [MeResult]: `Success` → `200` with the public person view, `Failure` → the neutral `401` from [toResponse]
 * (an orphaned session, indistinguishable from a missing one). The OpenAPI documentation lives on the
 * implemented [PersonControllerDoc].
 */
@Controller("/person")
class PersonController(
    private val meUseCase: MeUseCase,
    private val messages: MessagePort,
) : PersonControllerDoc {

    @Authenticated
    @Get("/me")
    @Status(HttpStatus.OK)
    override fun me(actor: AuthenticatedActor): HttpResponse<*> =
        when (val data = meUseCase(MeCommand(actor.personId))) {
            is MeResult.Failure -> data.error.toResponse(messages)
            is MeResult.Success -> HttpResponse.ok(data.person.toResponse())
        }
}
