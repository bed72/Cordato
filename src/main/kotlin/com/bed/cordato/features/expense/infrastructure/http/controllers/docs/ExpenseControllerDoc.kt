package com.bed.cordato.features.expense.infrastructure.http.controllers.docs

import jakarta.validation.Valid

import io.micronaut.http.MediaType
import io.micronaut.http.HttpRequest
import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Body

import io.swagger.v3.oas.annotations.tags.Tag
import io.swagger.v3.oas.annotations.Parameter
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.media.Schema
import io.swagger.v3.oas.annotations.media.Content
import io.swagger.v3.oas.annotations.responses.ApiResponse
import io.swagger.v3.oas.annotations.responses.ApiResponses
import io.swagger.v3.oas.annotations.security.SecurityRequirement

import com.bed.cordato.core.infrastructure.http.responses.DataResponse
import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse
import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor

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
@Tag(name = "Expense", description = "Registro e leitura de gastos da pessoa autenticada.")
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
            description = "Gasto registrado; `data` (`ExpenseResponse`) traz a visão pública do gasto criado.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = DataResponse::class))],
        ),
        ApiResponse(
            responseCode = "400",
            description = "Corpo ausente/inválido, ou campo que viola as restrições de borda (valor ausente/não-positivo, descrição acima do máximo).",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorsResponse::class))],
        ),
        ApiResponse(
            responseCode = "401",
            description = "Autenticação necessária; resposta neutra que não distingue token ausente/inválido de sessão órfã.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorsResponse::class))],
        ),
        ApiResponse(
            responseCode = "422",
            description = "Gasto bem-formado, porém rejeitado por uma invariante de domínio (valor ≤ 0, data futura, descrição longa demais); todas compartilham o `422`.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorsResponse::class))],
        ),
        ApiResponse(
            responseCode = "500",
            description = "Falha inesperada; a resposta é neutra e não vaza detalhes internos.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorsResponse::class))],
        ),
    )
    fun create(
        @Parameter(hidden = true) actor: AuthenticatedActor,
        @Body @Valid request: CreateExpenseRequest,
    ): HttpResponse<*>

    @Operation(
        operationId = "listExpenses",
        summary = "Lista os gastos da pessoa autenticada, paginados por cursor",
        description = "Retorna uma página, paginada por cursor (keyset), dos gastos pertencentes à pessoa " +
            "dona da sessão viva — o dono vem sempre do ator autenticado, nunca de parâmetro/corpo. O " +
            "envelope traz os itens na visão pública do gasto (id, valor em centavos, data, descrição) e um " +
            "próximo cursor, ausente na última página. A ordem é determinística: por data do gasto " +
            "decrescente (o mais recente primeiro), com desempate estável por id — a mesma dupla que " +
            "fundamenta o cursor. Uma pessoa sem nenhum gasto (ou cujo cursor já esgotou os gastos) recebe " +
            "`200` com uma página vazia, nunca `404`. Cada item carrega apenas o fato bruto e nunca " +
            "referencia orçamento. A rota é protegida: sem um `Authorization: Bearer` válido o guard de " +
            "borda recusa com o `401` neutro compartilhado, antes do handler.",
    )
    @SecurityRequirement(name = "bearerAuth")
    @ApiResponses(
        ApiResponse(
            responseCode = "200",
            description = "Página de gastos do ator autenticado; `data` (array de `ExpenseResponse`, " +
                "possivelmente vazio) traz os itens, `meta.pagination.next_cursor`/`links.next` presentes " +
                "apenas quando há próxima página.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = DataResponse::class))],
        ),
        ApiResponse(
            responseCode = "400",
            description = "`limit` acima do teto máximo, ou `cursor` malformado/ilegível.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorsResponse::class))],
        ),
        ApiResponse(
            responseCode = "401",
            description = "Autenticação necessária; resposta neutra que não distingue token ausente/inválido de sessão órfã.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorsResponse::class))],
        ),
        ApiResponse(
            responseCode = "500",
            description = "Falha inesperada; a resposta é neutra e não vaza detalhes internos.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorsResponse::class))],
        ),
    )
    fun list(
        @Parameter(hidden = true) request: HttpRequest<*>,
        @Parameter(hidden = true) actor: AuthenticatedActor,
        @Parameter(description = "Tamanho da página. Padrão 20; recusado acima de 100.", example = "20")
        limit: Int?,
        @Parameter(description = "Cursor opaco da página anterior; ausente para a primeira página.")
        cursor: String?,
    ): HttpResponse<*>
}
