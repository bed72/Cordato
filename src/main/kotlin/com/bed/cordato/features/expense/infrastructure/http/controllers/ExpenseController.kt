package com.bed.cordato.features.expense.infrastructure.http.controllers

import jakarta.validation.Valid
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Positive

import io.micronaut.validation.Validated

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpRequest
import io.micronaut.http.HttpResponse
import io.micronaut.http.uri.UriBuilder
import io.micronaut.http.annotation.Get
import io.micronaut.http.annotation.Body
import io.micronaut.http.annotation.Post
import io.micronaut.http.annotation.Status
import io.micronaut.http.annotation.Controller
import io.micronaut.http.annotation.QueryValue

import com.bed.cordato.core.infrastructure.http.responses.ok
import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.responses.created
import com.bed.cordato.core.infrastructure.http.responses.badRequest
import com.bed.cordato.core.infrastructure.http.responses.MetaResponse
import com.bed.cordato.core.infrastructure.http.responses.LinksResponse
import com.bed.cordato.core.infrastructure.http.responses.PaginationResponse
import com.bed.cordato.core.infrastructure.http.responses.PaginationMetaResponse

import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor
import com.bed.cordato.core.infrastructure.http.authentication.annotations.Authenticated

import com.bed.cordato.features.expense.domain.value_objects.ExpenseCursorValueObject

import com.bed.cordato.features.expense.application.driving.results.CreateExpenseResult
import com.bed.cordato.features.expense.application.driving.commands.ListExpensesCommand
import com.bed.cordato.features.expense.application.driving.use_cases.ListExpensesUseCase
import com.bed.cordato.features.expense.application.driving.use_cases.CreateExpenseUseCase

import com.bed.cordato.features.expense.infrastructure.http.mappers.errors.toResponse
import com.bed.cordato.features.expense.infrastructure.http.mappers.requests.toCursor
import com.bed.cordato.features.expense.infrastructure.http.mappers.requests.toCommand
import com.bed.cordato.features.expense.infrastructure.http.mappers.responses.toToken
import com.bed.cordato.features.expense.infrastructure.http.mappers.responses.toResponse
import com.bed.cordato.features.expense.infrastructure.http.requests.CreateExpenseRequest
import com.bed.cordato.features.expense.infrastructure.http.mappers.requests.DecodedCursor
import com.bed.cordato.features.expense.infrastructure.http.controllers.docs.ExpenseControllerDoc

/**
 * Expense's driving (primary/inbound) HTTP adapter: `POST /expenses` registers a spend for the authenticated
 * person. It mirrors identity's `PersonController` — a discovered `@Controller` (there is no factory way to
 * declare a route), depending only on the pure [CreateExpenseUseCase] bean and the [MessagePort].
 *
 * `@Authenticated` on the method makes the edge guard require a live session before the handler runs — a
 * missing/invalid/expired token is refused with the neutral `401` *before* here, so the use case is never
 * reached without a resolved caller. The [AuthenticatedActor] is injected by core's binder from the attribute
 * the filter wrote; the handler turns only its `personId` into the command's owner — the identity comes from
 * the actor, never the body, so a person can only register their own expense.
 *
 * `@Validated` + `@Valid` run the [CreateExpenseRequest]'s Bean Validation first: a violation is thrown as a
 * `ConstraintViolationException` (turned into a `400` by core's shared handler) before the use case. It
 * branches over the sealed result: `Success` → `201` with the public expense view (`@Status(CREATED)` also
 * documents the success code on the OpenAPI side); `Failure` → [toResponse] (`422`). The documentation lives
 * on the implemented [ExpenseControllerDoc].
 *
 * `GET /expenses` lists the authenticated actor's own expenses, cursor-paginated. It has no domain failure
 * branch (listing always succeeds, with zero or more items), so it returns `200` with the shared success
 * envelope — `data` as the item list, `meta.pagination.next_cursor`/`links.next` present only when there is
 * a next page, `links.self` built from the incoming [HttpRequest] so it survives the server's context-path —
 * an empty page when the actor has none, never `404`. `limit`/`cursor` are pure-transport query params,
 * validated only at this edge (`@Positive`/`@Max` on `limit`, bounded by [PaginationResponse.MAX_LIMIT] and
 * defaulting to [PaginationResponse.DEFAULT_LIMIT] — the shared cursor-pagination policy every context's
 * listing endpoint uses, so no feature drifts to its own page-size ceiling; a malformed `cursor` is decoded
 * by [toCursor] and refused here with a scalar `400`). The owner comes from the actor, never a
 * parameter/body, so a person can only ever list their own.
 */
@Validated
@Controller("/expenses")
class ExpenseController(
    private val messages: MessagePort,
    private val listExpensesUseCase: ListExpensesUseCase,
    private val createExpenseUseCase: CreateExpenseUseCase,
) : ExpenseControllerDoc {

    @Get
    @Authenticated
    @Status(HttpStatus.OK)
    override fun list(
        request: HttpRequest<*>,
        actor: AuthenticatedActor,
        @QueryValue
        @Positive(message = "{listExpenses.request.limit.positive}")
        @Max(value = PaginationResponse.MAX_LIMIT.toLong(), message = "{listExpenses.request.limit.max}")
        limit: Int?,
        @QueryValue cursor: String?,
    ): HttpResponse<*> = when (val decoded = cursor.toCursor()) {
        DecodedCursor.Absent -> page(request, actor.personId, limit, after = null)
        is DecodedCursor.Present -> page(request, actor.personId, limit, decoded.cursor)
        DecodedCursor.Malformed -> badRequest("MALFORMED_REQUEST", messages("error.malformed.message"))
    }

    @Post
    @Authenticated
    @Status(HttpStatus.CREATED)
    override fun create(actor: AuthenticatedActor, @Body @Valid request: CreateExpenseRequest): HttpResponse<*> =
        when (val data = createExpenseUseCase(request.toCommand(actor.personId))) {
            is CreateExpenseResult.Failure -> data.error.toResponse(messages)
            is CreateExpenseResult.Success -> created(data.expense.toResponse())
        }

    private fun page(request: HttpRequest<*>, personId: String, limit: Int?, after: ExpenseCursorValueObject?): HttpResponse<*> {
        val command = ListExpensesCommand(personId, limit ?: PaginationResponse.DEFAULT_LIMIT, after)
        val page = listExpensesUseCase(command)
        val cursor = page.nextCursor?.toToken()

        val self = request.uri.toString()
        val links = LinksResponse(
            self = self,
            next = cursor?.let { UriBuilder.of(request.uri).replaceQueryParam("cursor", it).build().toString() },
        )
        val meta = cursor?.let { MetaResponse(pagination = PaginationMetaResponse(nextCursor = it)) }

        return ok(page.toResponse(), meta, links)
    }
}
