package com.bed.cordato.features.budget.infrastructure.http.controllers

import jakarta.validation.Valid

import io.micronaut.validation.Validated

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Get
import io.micronaut.http.annotation.Body
import io.micronaut.http.annotation.Post
import io.micronaut.http.annotation.Status
import io.micronaut.http.annotation.Controller

import com.bed.cordato.core.infrastructure.http.responses.ok
import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.responses.created

import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor
import com.bed.cordato.core.infrastructure.http.authentication.annotations.Authenticated

import com.bed.cordato.features.budget.application.driving.results.CreateBudgetResult
import com.bed.cordato.features.budget.application.driving.use_cases.CreateBudgetUseCase
import com.bed.cordato.features.budget.application.driving.commands.GetActiveBudgetCommand
import com.bed.cordato.features.budget.application.driving.use_cases.GetActiveBudgetUseCase

import com.bed.cordato.features.budget.infrastructure.http.mappers.errors.toResponse
import com.bed.cordato.features.budget.infrastructure.http.mappers.requests.toCommand
import com.bed.cordato.features.budget.infrastructure.http.mappers.responses.toResponse
import com.bed.cordato.features.budget.infrastructure.http.requests.CreateBudgetRequest
import com.bed.cordato.features.budget.infrastructure.http.controllers.docs.BudgetControllerDoc

/**
 * Budget's driving (primary/inbound) HTTP adapter: `POST /budgets` creates a budget for the authenticated
 * person. It mirrors expense's `ExpenseController` — a discovered `@Controller` (there is no factory way to
 * declare a route), depending only on the pure [CreateBudgetUseCase] bean and the [MessagePort].
 *
 * `@Authenticated` on the method makes the edge guard require a live session before the handler runs — a
 * missing/invalid/expired token is refused with the neutral `401` *before* here, so the use case is never
 * reached without a resolved caller. The [AuthenticatedActor] is injected by core's binder from the attribute
 * the filter wrote; the handler turns only its `personId` into the command's owner — the identity comes from
 * the actor, never the body, so a person can only create their own budget.
 *
 * `@Validated` + `@Valid` run the [CreateBudgetRequest]'s Bean Validation first: a violation is thrown as a
 * `ConstraintViolationException` (turned into a `400` by core's shared handler) before the use case. It
 * branches over the sealed result: `Success` → `201` with the public budget view (`@Status(CREATED)` also
 * documents the success code on the OpenAPI side); `Failure` → [toResponse] (`422`). The documentation lives
 * on the implemented [BudgetControllerDoc].
 *
 * `GET /budgets/active` reads the authenticated actor's active budget. It has no domain failure branch (not
 * having one today is a normal, valid answer), so it always returns `200` with the shared success envelope
 * — `data` holding the public view, or `null` when [GetActiveBudgetUseCase] finds nothing, never `404`.
 */
@Validated
@Controller("/budgets")
class BudgetController(
    private val messages: MessagePort,
    private val createBudgetUseCase: CreateBudgetUseCase,
    private val getActiveBudgetUseCase: GetActiveBudgetUseCase,
) : BudgetControllerDoc {

    @Post
    @Authenticated
    @Status(HttpStatus.CREATED)
    override fun create(actor: AuthenticatedActor, @Body @Valid request: CreateBudgetRequest): HttpResponse<*> =
        when (val data = createBudgetUseCase(request.toCommand(actor.personId))) {
            is CreateBudgetResult.Failure -> data.error.toResponse(messages)
            is CreateBudgetResult.Success -> created(data.budget.toResponse())
        }

    @Get("/active")
    @Authenticated
    @Status(HttpStatus.OK)
    override fun active(actor: AuthenticatedActor): HttpResponse<*> =
        ok(getActiveBudgetUseCase(GetActiveBudgetCommand(actor.personId))?.toResponse())
}
