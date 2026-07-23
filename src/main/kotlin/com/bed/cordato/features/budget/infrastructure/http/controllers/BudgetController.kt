package com.bed.cordato.features.budget.infrastructure.http.controllers

import jakarta.validation.Valid

import io.micronaut.validation.Validated

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Get
import io.micronaut.http.annotation.Body
import io.micronaut.http.annotation.Post
import io.micronaut.http.annotation.Patch
import io.micronaut.http.annotation.Delete
import io.micronaut.http.annotation.Status
import io.micronaut.http.annotation.Controller
import io.micronaut.http.annotation.PathVariable

import com.bed.cordato.core.infrastructure.http.responses.ok
import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.responses.created

import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor
import com.bed.cordato.core.infrastructure.http.authentication.annotations.Authenticated

import com.bed.cordato.features.budget.application.driving.results.CreateBudgetResult
import com.bed.cordato.features.budget.application.driving.results.UpdateBudgetResult
import com.bed.cordato.features.budget.application.driving.results.DeleteBudgetResult

import com.bed.cordato.features.budget.application.driving.commands.DeleteBudgetCommand
import com.bed.cordato.features.budget.application.driving.commands.GetActiveBudgetCommand
import com.bed.cordato.features.budget.application.driving.commands.GetDefaultBudgetCommand

import com.bed.cordato.features.budget.application.driving.use_cases.CreateBudgetUseCase
import com.bed.cordato.features.budget.application.driving.use_cases.UpdateBudgetUseCase
import com.bed.cordato.features.budget.application.driving.use_cases.DeleteBudgetUseCase
import com.bed.cordato.features.budget.application.driving.use_cases.GetActiveBudgetUseCase
import com.bed.cordato.features.budget.application.driving.use_cases.GetDefaultBudgetUseCase

import com.bed.cordato.features.budget.infrastructure.http.mappers.errors.toResponse
import com.bed.cordato.features.budget.infrastructure.http.mappers.requests.toCommand
import com.bed.cordato.features.budget.infrastructure.http.mappers.responses.toResponse
import com.bed.cordato.features.budget.infrastructure.http.requests.CreateBudgetRequest
import com.bed.cordato.features.budget.infrastructure.http.requests.UpdateBudgetRequest
import com.bed.cordato.features.budget.infrastructure.http.controllers.docs.BudgetControllerDoc
import com.bed.cordato.features.budget.infrastructure.http.mappers.responses.toDefaultBudgetResponse

/**
 * Budget's driving (primary/inbound) HTTP adapter: `POST /budgets` creates a budget for the authenticated
 * person. It mirrors expense's `ExpenseController` — a discovered `@Controller` (there is no factory way to
 * declare a route), depending only on the pure use-case beans and the [MessagePort].
 *
 * `@Authenticated` on the method makes the edge guard require a live session before the handler runs — a
 * missing/invalid/expired token is refused with the neutral `401` *before* here, so the use case is never
 * reached without a resolved caller. The [AuthenticatedActor] is injected by core's binder from the attribute
 * the filter wrote; every handler turns only its `personId` into the command's owner — the identity comes
 * from the actor, never the body, so a person can only act on their own budget.
 *
 * `@Validated` + `@Valid` run the [CreateBudgetRequest]/[UpdateBudgetRequest]'s Bean Validation first: a
 * violation is thrown as a `ConstraintViolationException` (turned into a `400` by core's shared handler)
 * before the use case. `create` branches over the sealed result: `Success` → `201` with the public budget
 * view (`@Status(CREATED)` also documents the success code on the OpenAPI side); `Failure` → [toResponse]
 * (`422`). The documentation lives on the implemented [BudgetControllerDoc].
 *
 * `GET /budgets/active` reads the authenticated actor's active budget. It has no domain failure branch (not
 * having one today is a normal, valid answer), so it always returns `200` with the shared success envelope
 * — `data` holding the public view, or `null` when [GetActiveBudgetUseCase] finds nothing, never `404`.
 *
 * `GET /budgets/default` reads the authenticated actor's default budget ("no budget"): the total spent
 * outside of every live budget's period. Unlike `/active`, there is no entity being looked for — the
 * grouping is fabricated and always "exists" — so `data` is always a present object, never `null`.
 *
 * `PATCH /budgets/{id}` edits a live budget of the actor: the `id` comes from the URL path (bound via
 * [PathVariable]), never the body. `DELETE /budgets/{id}` soft-deletes it the same way. Both branch over
 * their sealed result: `Success` → `200` with the public budget view; `Failure` → [toResponse], which for
 * `BudgetNotFound` (an unknown id, one belonging to another person, or an already-removed one — all
 * indistinguishable) is the API's first `404`.
 */
@Validated
@Controller("/budgets")
class BudgetController(
    private val messages: MessagePort,
    private val createBudgetUseCase: CreateBudgetUseCase,
    private val updateBudgetUseCase: UpdateBudgetUseCase,
    private val deleteBudgetUseCase: DeleteBudgetUseCase,
    private val getActiveBudgetUseCase: GetActiveBudgetUseCase,
    private val getDefaultBudgetUseCase: GetDefaultBudgetUseCase,
) : BudgetControllerDoc {

    @Post
    @Authenticated
    @Status(HttpStatus.CREATED)
    override fun create(actor: AuthenticatedActor, @Body @Valid request: CreateBudgetRequest): HttpResponse<*> =
        when (val data = createBudgetUseCase(request.toCommand(actor.personId))) {
            is CreateBudgetResult.Failure -> data.error.toResponse(messages)
            is CreateBudgetResult.Success -> created(data.budget.toResponse())
        }

    @Patch("/{id}")
    @Authenticated
    @Status(HttpStatus.OK)
    override fun update(
        actor: AuthenticatedActor,
        @PathVariable id: String,
        @Body @Valid request: UpdateBudgetRequest,
    ): HttpResponse<*> =
        when (val data = updateBudgetUseCase(request.toCommand(id, actor.personId))) {
            is UpdateBudgetResult.Failure -> data.error.toResponse(messages)
            is UpdateBudgetResult.Success -> ok(data.budget.toResponse())
        }

    @Delete("/{id}")
    @Authenticated
    @Status(HttpStatus.OK)
    override fun delete(actor: AuthenticatedActor, @PathVariable id: String): HttpResponse<*> =
        when (val data = deleteBudgetUseCase(DeleteBudgetCommand(budgetId = id, personId = actor.personId))) {
            is DeleteBudgetResult.Failure -> data.error.toResponse(messages)
            is DeleteBudgetResult.Success -> ok(data.budget.toResponse())
        }

    @Get("/active")
    @Authenticated
    @Status(HttpStatus.OK)
    override fun active(actor: AuthenticatedActor): HttpResponse<*> =
        ok(getActiveBudgetUseCase(GetActiveBudgetCommand(actor.personId))?.toResponse())

    @Get("/default")
    @Authenticated
    @Status(HttpStatus.OK)
    override fun default(actor: AuthenticatedActor): HttpResponse<*> =
        ok(getDefaultBudgetUseCase(GetDefaultBudgetCommand(actor.personId)).toDefaultBudgetResponse())
}
