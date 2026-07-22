package com.bed.cordato.features.budget.infrastructure.http.controllers.docs

import jakarta.validation.Valid

import io.micronaut.http.MediaType
import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Body

import io.swagger.v3.oas.annotations.tags.Tag
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.Parameter
import io.swagger.v3.oas.annotations.media.Schema
import io.swagger.v3.oas.annotations.media.Content
import io.swagger.v3.oas.annotations.responses.ApiResponse
import io.swagger.v3.oas.annotations.responses.ApiResponses
import io.swagger.v3.oas.annotations.security.SecurityRequirement

import com.bed.cordato.features.budget.infrastructure.http.requests.CreateBudgetRequest

import com.bed.cordato.core.infrastructure.http.responses.DataResponse
import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse
import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor

/**
 * OpenAPI documentation for budget's create route, kept off the controller so it stays a thin routing
 * adapter. Micronaut inherits an interface's annotation metadata onto the implementing method, so the
 * micronaut-openapi processor picks up the `@Operation`/`@ApiResponse`/`@SecurityRequirement` declared here
 * when it documents the route [com.bed.cordato.features.budget.infrastructure.http.controllers.BudgetController]
 * registers with `@Post`.
 *
 * `@SecurityRequirement(name = "bearerAuth")` references the Bearer scheme declared globally in core's
 * `OpenApiDefinition`, so the Swagger UI shows the padlock and lets the caller send a token. The
 * [AuthenticatedActor] parameter is hidden: it is resolved from a request attribute by the edge binder, not
 * from the wire, so it is never a documented request parameter. This is a documentation artefact of
 * infrastructure, not an application port — it introduces no driving-side contract.
 */
@Tag(name = "Budget", description = "Criação e leitura do orçamento (teto planejado por intervalo de datas) da pessoa autenticada.")
interface BudgetControllerDoc {

    @Operation(
        operationId = "createBudget",
        summary = "Cria um orçamento da pessoa autenticada",
        description = "Cria um novo orçamento (o teto planejado: valor, intervalo de datas, anotação) " +
            "pertencente à pessoa dona da sessão viva — o dono vem sempre do ator autenticado, nunca do " +
            "corpo — e retorna a visão pública do orçamento criado (id, valor em centavos, data de início, " +
            "data de fim, anotação). O valor é exato, em centavos, e sempre maior que zero. O intervalo de " +
            "datas tem início e fim, ambos incluídos; o fim nunca pode ser anterior ao início. A anotação é " +
            "opcional, aparada e limitada. A mesma pessoa nunca pode ter dois orçamentos vivos cujos " +
            "intervalos se sobreponham, mesmo em um dia de fronteira. O orçamento nunca referencia gastos. " +
            "A rota é protegida: sem um `Authorization: Bearer` válido o guard de borda recusa com o `401` " +
            "neutro compartilhado, antes do handler. Um corpo que a borda rejeita responde `400`; um " +
            "orçamento bem-formado que o domínio recusa (valor ≤ 0, intervalo inválido, anotação longa " +
            "demais, sobreposição) responde `422`.",
    )
    @SecurityRequirement(name = "bearerAuth")
    @ApiResponses(
        ApiResponse(
            responseCode = "201",
            description = "Orçamento criado; `data` (`BudgetResponse`) traz a visão pública do orçamento criado.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = DataResponse::class))],
        ),
        ApiResponse(
            responseCode = "400",
            description = "Corpo ausente/inválido, ou campo que viola as restrições de borda (valor ausente/não-positivo, datas ausentes, anotação acima do máximo).",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorsResponse::class))],
        ),
        ApiResponse(
            responseCode = "401",
            description = "Autenticação necessária; resposta neutra que não distingue token ausente/inválido de sessão órfã.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorsResponse::class))],
        ),
        ApiResponse(
            responseCode = "422",
            description = "Orçamento bem-formado, porém rejeitado por uma invariante de domínio (valor ≤ 0, intervalo inválido, anotação longa demais, sobreposição com outro orçamento vivo); todas compartilham o `422`.",
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
        @Body @Valid request: CreateBudgetRequest,
    ): HttpResponse<*>

    @Operation(
        operationId = "getActiveBudget",
        summary = "Retorna o orçamento ativo da pessoa autenticada",
        description = "Retorna o orçamento vivo cujo intervalo cobre a data de hoje, acompanhado do gasto " +
            "somado e do valor restante no intervalo — ambos recalculados a cada leitura e nunca " +
            "persistidos; o restante pode ser negativo quando o orçamento está estourado, o que não é um " +
            "erro. Quando a pessoa não tem nenhum orçamento vivo cobrindo hoje, o sistema responde `200` " +
            "com `data` igual a `null` — a ausência de orçamento ativo é um resultado de sucesso, nunca um " +
            "erro. A rota é protegida: sem um `Authorization: Bearer` válido o guard de borda recusa com o " +
            "`401` neutro compartilhado, antes do handler.",
    )
    @SecurityRequirement(name = "bearerAuth")
    @ApiResponses(
        ApiResponse(
            responseCode = "200",
            description = "`data` (`ActiveBudgetResponse`, nulável) traz o orçamento ativo de hoje, ou `null` quando não há nenhum.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = DataResponse::class, nullable = true))],
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
    fun active(@Parameter(hidden = true) actor: AuthenticatedActor): HttpResponse<*>
}
