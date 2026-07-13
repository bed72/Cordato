package com.bed.cordato.features.expense.infrastructure.http.controllers.docs

import io.micronaut.http.MediaType
import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Body

import jakarta.validation.Valid

import io.swagger.v3.oas.annotations.tags.Tag
import io.swagger.v3.oas.annotations.Parameter
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.media.Schema
import io.swagger.v3.oas.annotations.media.Content
import io.swagger.v3.oas.annotations.media.ArraySchema
import io.swagger.v3.oas.annotations.responses.ApiResponse
import io.swagger.v3.oas.annotations.responses.ApiResponses
import io.swagger.v3.oas.annotations.security.SecurityRequirement

import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse
import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor

import com.bed.cordato.features.expense.infrastructure.http.responses.ExpenseResponse
import com.bed.cordato.features.expense.infrastructure.http.requests.CreateExpenseRequest

/**
 * OpenAPI documentation for expense's register route, kept off the controller so it stays a thin routing
 * adapter. Micronaut inherits an interface's annotation metadata onto the implementing method, so the
 * micronaut-openapi processor picks up the `@Operation`/`@ApiResponse`/`@SecurityRequirement` declared here
 * when it documents the route [com.bed.cordato.features.expense.infrastructure.http.controllers.ExpenseController] registers with `@Post`.
 *
 * `@SecurityRequirement(name = "bearerAuth")` references the Bearer scheme declared globally in core's
 * `OpenApiDefinition`, so the Swagger UI shows the padlock and lets the caller send a token. The
 * [AuthenticatedActor] parameter is hidden: it is resolved from a request attribute by the edge binder, not
 * from the wire, so it is never a documented request parameter. This is a documentation artefact of
 * infrastructure, not an application port — it introduces no driving-side contract.
 */
@Tag(name = "Expense", description = "Registro de gastos da pessoa autenticada.")
interface ExpenseControllerDoc {

    @Operation(
        operationId = "createExpense",
        summary = "Registra um gasto da pessoa autenticada",
        description = "Registra um novo gasto (o fato atômico: valor, data, descrição) pertencente à pessoa " +
            "dona da sessão viva — o dono vem sempre do ator autenticado, nunca do corpo — e retorna a visão " +
            "pública do gasto criado (id, valor em centavos, data, descrição). O valor é exato, em centavos, e " +
            "sempre maior que zero. A data é opcional: ausente assume hoje; informada, pode ser hoje ou no " +
            "passado, nunca no futuro. A descrição é opcional, aparada e limitada. O gasto nunca referencia " +
            "orçamento. A rota é protegida: sem um `Authorization: Bearer` válido o guard de borda recusa com " +
            "o `401` neutro compartilhado, antes do handler. Um corpo que a borda rejeita responde `400`; um " +
            "gasto bem-formado que o domínio recusa (valor ≤ 0, data futura, descrição longa demais) responde " +
            "`422`.",
    )
    @SecurityRequirement(name = "bearerAuth")
    @ApiResponses(
        ApiResponse(
            responseCode = "201",
            description = "Gasto registrado; retorna a visão pública do gasto criado.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ExpenseResponse::class))],
        ),
        ApiResponse(
            responseCode = "400",
            description = "Corpo ausente/inválido, ou campo que viola as restrições de borda (valor ausente/não-positivo, descrição acima do máximo).",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
        ApiResponse(
            responseCode = "401",
            description = "Autenticação necessária; resposta neutra que não distingue token ausente/inválido de sessão órfã.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
        ApiResponse(
            responseCode = "422",
            description = "Gasto bem-formado, porém rejeitado por uma invariante de domínio (valor ≤ 0, data futura, descrição longa demais); todas compartilham o `422`.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
        ApiResponse(
            responseCode = "500",
            description = "Falha inesperada; a resposta é neutra e não vaza detalhes internos.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
    )
    fun create(
        @Parameter(hidden = true) actor: AuthenticatedActor,
        @Body @Valid request: CreateExpenseRequest,
    ): HttpResponse<*>

    @Operation(
        operationId = "listExpenses",
        summary = "Lista os gastos da pessoa autenticada",
        description = "Retorna todos, e somente, os gastos pertencentes à pessoa dona da sessão viva — o dono " +
            "vem sempre do ator autenticado, nunca de parâmetro/filtro/corpo, de modo que uma pessoa não " +
            "consegue listar os gastos de outra. A resposta é um array na visão pública do gasto (id, valor em " +
            "centavos, data, descrição), ordenado pela data do gasto de forma decrescente (o mais recente " +
            "primeiro) com desempate estável por id. Uma pessoa sem nenhum gasto recebe `200` com um array " +
            "vazio, nunca `404`. Nenhum item referencia orçamento. A rota é protegida: sem um `Authorization: " +
            "Bearer` válido o guard de borda recusa com o `401` neutro compartilhado, antes do handler.",
    )
    @SecurityRequirement(name = "bearerAuth")
    @ApiResponses(
        ApiResponse(
            responseCode = "200",
            description = "Lista (possivelmente vazia) dos gastos da pessoa autenticada, ordenada por data decrescente.",
            content = [Content(
                mediaType = MediaType.APPLICATION_JSON,
                array = ArraySchema(schema = Schema(implementation = ExpenseResponse::class)),
            )],
        ),
        ApiResponse(
            responseCode = "401",
            description = "Autenticação necessária; resposta neutra que não distingue token ausente/inválido de sessão órfã.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
        ApiResponse(
            responseCode = "500",
            description = "Falha inesperada; a resposta é neutra e não vaza detalhes internos.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
    )
    fun list(@Parameter(hidden = true) actor: AuthenticatedActor): HttpResponse<*>
}
