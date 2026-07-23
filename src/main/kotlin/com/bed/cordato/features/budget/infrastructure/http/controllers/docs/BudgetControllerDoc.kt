package com.bed.cordato.features.budget.infrastructure.http.controllers.docs

import jakarta.validation.Valid

import io.micronaut.http.MediaType
import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Body
import io.micronaut.http.annotation.PathVariable

import io.swagger.v3.oas.annotations.tags.Tag
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.Parameter
import io.swagger.v3.oas.annotations.media.Schema
import io.swagger.v3.oas.annotations.media.Content
import io.swagger.v3.oas.annotations.media.ExampleObject
import io.swagger.v3.oas.annotations.responses.ApiResponse
import io.swagger.v3.oas.annotations.responses.ApiResponses
import io.swagger.v3.oas.annotations.security.SecurityRequirement

import com.bed.cordato.features.budget.infrastructure.http.requests.CreateBudgetRequest
import com.bed.cordato.features.budget.infrastructure.http.requests.UpdateBudgetRequest

import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse
import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor

/**
 * Real example payloads for the shared [ErrorsResponse] shape, one per status/code this controller's routes
 * actually emit — see [com.bed.cordato.core.infrastructure.http.responses.ErrorResponse] for the builders and
 * `i18n/messages.properties` for the exact resolved text. Without an explicit example, every response
 * referencing [ErrorsResponse] would render the same schema-level placeholder regardless of its real status,
 * which is misleading (a `401`/`500` showing a `422` payload).
 */
private const val MALFORMED_400 =
    """{"errors":[{"status":"400","code":"MALFORMED_REQUEST","message":"O corpo da requisição está ausente ou é inválido."}]}"""
private const val UNAUTHENTICATED_401 =
    """{"errors":[{"status":"401","code":"UNAUTHENTICATED","message":"Autenticação necessária."}]}"""
private const val BUDGET_NOT_FOUND_404 =
    """{"errors":[{"status":"404","code":"BUDGET_NOT_FOUND","message":"Orçamento não encontrado."}]}"""
private const val INTERNAL_500 =
    """{"errors":[{"status":"500","code":"INTERNAL_ERROR","message":"Ocorreu um erro inesperado. Tente novamente mais tarde."}]}"""

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
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = BudgetDataResponse::class))],
        ),
        ApiResponse(
            responseCode = "400",
            description = "Corpo ausente/inválido, ou campo que viola as restrições de borda (valor ausente/não-positivo, datas ausentes, anotação acima do máximo).",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [ExampleObject(value = MALFORMED_400)],
                ),
            ],
        ),
        ApiResponse(
            responseCode = "401",
            description = "Autenticação necessária; resposta neutra que não distingue token ausente/inválido de sessão órfã.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [ExampleObject(value = UNAUTHENTICATED_401)],
                ),
            ],
        ),
        ApiResponse(
            responseCode = "422",
            description = "Orçamento bem-formado, porém rejeitado por uma invariante de domínio (valor ≤ 0, intervalo inválido, anotação longa demais, sobreposição com outro orçamento vivo); todas compartilham o `422`.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [
                        ExampleObject(
                            name = "invalid_amount",
                            summary = "Valor não positivo",
                            value = """{"errors":[{"status":"422","code":"INVALID_AMOUNT","message":"O valor do orçamento deve ser maior que zero."}]}""",
                        ),
                        ExampleObject(
                            name = "invalid_period",
                            summary = "Fim anterior ao início",
                            value = """{"errors":[{"status":"422","code":"INVALID_PERIOD","message":"A data de fim não pode ser anterior à data de início."}]}""",
                        ),
                        ExampleObject(
                            name = "invalid_note",
                            summary = "Anotação longa demais",
                            value = """{"errors":[{"status":"422","code":"INVALID_NOTE","message":"A anotação do orçamento excede o comprimento máximo."}]}""",
                        ),
                        ExampleObject(
                            name = "overlapping_budget",
                            summary = "Sobreposição com orçamento vivo",
                            value = """{"errors":[{"status":"422","code":"OVERLAPPING_BUDGET","message":"Já existe um orçamento vivo que se sobrepõe a esse intervalo de datas."}]}""",
                        ),
                    ],
                ),
            ],
        ),
        ApiResponse(
            responseCode = "500",
            description = "Falha inesperada; a resposta é neutra e não vaza detalhes internos.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [ExampleObject(value = INTERNAL_500)],
                ),
            ],
        ),
    )
    fun create(
        @Parameter(hidden = true) actor: AuthenticatedActor,
        @Body @Valid request: CreateBudgetRequest,
    ): HttpResponse<*>

    @Operation(
        operationId = "updateBudget",
        summary = "Edita um orçamento vivo da pessoa autenticada",
        description = "Edita o valor, o intervalo de datas e a anotação de um orçamento **vivo** " +
            "pertencente à pessoa dona da sessão viva, identificado pelo `id` na URL — o dono vem sempre " +
            "do ator autenticado, nunca do corpo. Os três campos mutáveis são sempre reenviados juntos, " +
            "mesmo formato da criação; não há edição de um único campo isolado. Reaplica as mesmas regras " +
            "de domínio da criação (valor > 0, intervalo com fim ≥ início, anotação opcional/aparada/" +
            "limitada) e a invariante de não-sobreposição contra os demais orçamentos vivos da pessoa " +
            "(o próprio orçamento editado nunca compete contra si mesmo). Retorna a visão pública do " +
            "orçamento atualizado. Um `id` que não existe, que já está removido, ou que pertence a outra " +
            "pessoa produzem o **mesmo** `404` — o sistema nunca revela, a quem não é dono, se um `id` de " +
            "orçamento existe. A rota é protegida: sem um `Authorization: Bearer` válido o guard de borda " +
            "recusa com o `401` neutro compartilhado, antes do handler.",
    )
    @SecurityRequirement(name = "bearerAuth")
    @ApiResponses(
        ApiResponse(
            responseCode = "200",
            description = "Orçamento atualizado; `data` (`BudgetResponse`) traz a visão pública do orçamento editado.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = BudgetDataResponse::class))],
        ),
        ApiResponse(
            responseCode = "400",
            description = "Corpo ausente/inválido, ou campo que viola as restrições de borda (valor ausente/não-positivo, datas ausentes, anotação acima do máximo).",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [ExampleObject(value = MALFORMED_400)],
                ),
            ],
        ),
        ApiResponse(
            responseCode = "401",
            description = "Autenticação necessária; resposta neutra que não distingue token ausente/inválido de sessão órfã.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [ExampleObject(value = UNAUTHENTICATED_401)],
                ),
            ],
        ),
        ApiResponse(
            responseCode = "404",
            description = "Orçamento não encontrado: `id` inexistente, já removido, ou pertencente a outra pessoa — as três situações produzem a mesma resposta.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [ExampleObject(value = BUDGET_NOT_FOUND_404)],
                ),
            ],
        ),
        ApiResponse(
            responseCode = "422",
            description = "Orçamento bem-formado, porém rejeitado por uma invariante de domínio (valor ≤ 0, intervalo inválido, anotação longa demais, sobreposição com outro orçamento vivo); todas compartilham o `422`.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [
                        ExampleObject(
                            name = "invalid_amount",
                            summary = "Valor não positivo",
                            value = """{"errors":[{"status":"422","code":"INVALID_AMOUNT","message":"O valor do orçamento deve ser maior que zero."}]}""",
                        ),
                        ExampleObject(
                            name = "invalid_period",
                            summary = "Fim anterior ao início",
                            value = """{"errors":[{"status":"422","code":"INVALID_PERIOD","message":"A data de fim não pode ser anterior à data de início."}]}""",
                        ),
                        ExampleObject(
                            name = "invalid_note",
                            summary = "Anotação longa demais",
                            value = """{"errors":[{"status":"422","code":"INVALID_NOTE","message":"A anotação do orçamento excede o comprimento máximo."}]}""",
                        ),
                        ExampleObject(
                            name = "overlapping_budget",
                            summary = "Sobreposição com orçamento vivo",
                            value = """{"errors":[{"status":"422","code":"OVERLAPPING_BUDGET","message":"Já existe um orçamento vivo que se sobrepõe a esse intervalo de datas."}]}""",
                        ),
                    ],
                ),
            ],
        ),
        ApiResponse(
            responseCode = "500",
            description = "Falha inesperada; a resposta é neutra e não vaza detalhes internos.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [ExampleObject(value = INTERNAL_500)],
                ),
            ],
        ),
    )
    fun update(
        @Parameter(hidden = true) actor: AuthenticatedActor,
        @Parameter(description = "Identificador do orçamento a editar.") @PathVariable id: String,
        @Body @Valid request: UpdateBudgetRequest,
    ): HttpResponse<*>

    @Operation(
        operationId = "deleteBudget",
        summary = "Remove (soft-delete) um orçamento vivo da pessoa autenticada",
        description = "Remove de forma recuperável (soft-delete) um orçamento **vivo** pertencente à " +
            "pessoa dona da sessão viva, identificado pelo `id` na URL — o dono vem sempre do ator " +
            "autenticado. O orçamento passa para o estado removido; nenhum dado é apagado fisicamente. A " +
            "partir da remoção, o orçamento deixa de competir na invariante de não-sobreposição e de " +
            "aparecer nas visões ativa/`default`; nenhum gasto é tocado. Retorna a visão pública do " +
            "orçamento, já no estado removido. Um `id` que não existe, que já está removido, ou que " +
            "pertence a outra pessoa produzem o **mesmo** `404` — o sistema nunca revela, a quem não é " +
            "dono, se um `id` de orçamento existe. A rota é protegida: sem um `Authorization: Bearer` " +
            "válido o guard de borda recusa com o `401` neutro compartilhado, antes do handler.",
    )
    @SecurityRequirement(name = "bearerAuth")
    @ApiResponses(
        ApiResponse(
            responseCode = "200",
            description = "Orçamento removido; `data` (`BudgetResponse`) traz a visão pública do orçamento, já no estado removido.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = BudgetDataResponse::class))],
        ),
        ApiResponse(
            responseCode = "401",
            description = "Autenticação necessária; resposta neutra que não distingue token ausente/inválido de sessão órfã.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [ExampleObject(value = UNAUTHENTICATED_401)],
                ),
            ],
        ),
        ApiResponse(
            responseCode = "404",
            description = "Orçamento não encontrado: `id` inexistente, já removido, ou pertencente a outra pessoa — as três situações produzem a mesma resposta.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [ExampleObject(value = BUDGET_NOT_FOUND_404)],
                ),
            ],
        ),
        ApiResponse(
            responseCode = "500",
            description = "Falha inesperada; a resposta é neutra e não vaza detalhes internos.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [ExampleObject(value = INTERNAL_500)],
                ),
            ],
        ),
    )
    fun delete(
        @Parameter(hidden = true) actor: AuthenticatedActor,
        @Parameter(description = "Identificador do orçamento a remover.") @PathVariable id: String,
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
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ActiveBudgetDataResponse::class))],
        ),
        ApiResponse(
            responseCode = "401",
            description = "Autenticação necessária; resposta neutra que não distingue token ausente/inválido de sessão órfã.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [ExampleObject(value = UNAUTHENTICATED_401)],
                ),
            ],
        ),
        ApiResponse(
            responseCode = "500",
            description = "Falha inesperada; a resposta é neutra e não vaza detalhes internos.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [ExampleObject(value = INTERNAL_500)],
                ),
            ],
        ),
    )
    fun active(@Parameter(hidden = true) actor: AuthenticatedActor): HttpResponse<*>

    @Operation(
        operationId = "getDefaultBudget",
        summary = "Retorna o orçamento padrão (\"sem orçamento\") da pessoa autenticada",
        description = "Retorna o gasto somado, em centavos, de todos os gastos vivos do ator que não caem " +
            "dentro do intervalo de nenhum orçamento vivo dele — um agrupamento fabricado, nunca um " +
            "orçamento de verdade, sem `id`/`valor`/`anotação`. O valor é recalculado a cada leitura e " +
            "nunca persistido. Ao contrário de `/active`, não há um conceito de ausência aqui: o " +
            "agrupamento sempre \"existe\", então a rota sempre responde `200` com `data` presente, mesmo " +
            "quando o total é zero. A rota é protegida: sem um `Authorization: Bearer` válido o guard de " +
            "borda recusa com o `401` neutro compartilhado, antes do handler.",
    )
    @SecurityRequirement(name = "bearerAuth")
    @ApiResponses(
        ApiResponse(
            responseCode = "200",
            description = "`data` (`DefaultBudgetResponse`, sempre presente) traz o gasto somado fora de qualquer orçamento vivo.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = DefaultBudgetDataResponse::class))],
        ),
        ApiResponse(
            responseCode = "401",
            description = "Autenticação necessária; resposta neutra que não distingue token ausente/inválido de sessão órfã.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [ExampleObject(value = UNAUTHENTICATED_401)],
                ),
            ],
        ),
        ApiResponse(
            responseCode = "500",
            description = "Falha inesperada; a resposta é neutra e não vaza detalhes internos.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [ExampleObject(value = INTERNAL_500)],
                ),
            ],
        ),
    )
    fun default(@Parameter(hidden = true) actor: AuthenticatedActor): HttpResponse<*>
}
