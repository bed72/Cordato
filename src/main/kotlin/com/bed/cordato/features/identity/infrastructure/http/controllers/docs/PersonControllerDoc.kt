package com.bed.cordato.features.identity.infrastructure.http.controllers.docs

import io.micronaut.http.HttpResponse
import io.micronaut.http.MediaType
import io.micronaut.http.annotation.Body

import jakarta.validation.Valid

import io.swagger.v3.oas.annotations.Parameter
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.tags.Tag
import io.swagger.v3.oas.annotations.media.Content
import io.swagger.v3.oas.annotations.media.Schema
import io.swagger.v3.oas.annotations.responses.ApiResponse
import io.swagger.v3.oas.annotations.responses.ApiResponses
import io.swagger.v3.oas.annotations.security.SecurityRequirement

import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse
import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor

import com.bed.cordato.features.identity.infrastructure.http.requests.UpdateNameRequest
import com.bed.cordato.features.identity.infrastructure.http.requests.UpdateEmailRequest
import com.bed.cordato.features.identity.infrastructure.http.responses.PersonResponse

/**
 * OpenAPI documentation for identity's authenticated person routes, kept off the controller so it stays a
 * thin routing adapter. Micronaut inherits an interface's annotation metadata onto the implementing method,
 * so the micronaut-openapi processor picks up the `@Operation`/`@ApiResponse`/`@SecurityRequirement`
 * declared here when it documents the route [com.bed.cordato.features.identity.infrastructure.http.controllers.PersonController] registers with `@Get`.
 *
 * `@SecurityRequirement(name = "bearerAuth")` references the Bearer scheme declared globally in core's
 * `OpenApiDefinition`, so the Swagger UI shows the padlock and lets the caller send a token. The
 * [AuthenticatedActor] parameter is hidden: it is resolved from a request attribute by the edge binder, not
 * from the wire, so it is never a documented request parameter. This is a documentation artefact of
 * infrastructure, not an application port — it introduces no driving-side contract.
 */
@Tag(name = "Person", description = "Consulta de dados da pessoa autenticada.")
interface PersonControllerDoc {

    @Operation(
        operationId = "me",
        summary = "Recupera a pessoa autenticada",
        description = "Retorna a visão pública (id, nome, e-mail) da pessoa dona da sessão viva. A rota é " +
            "protegida: sem um `Authorization: Bearer` válido o guard de borda recusa com o `401` neutro " +
            "compartilhado, antes do handler. Uma sessão órfã (pessoa não mais ativa) colapsa no mesmo " +
            "`401`, indistinguível de um token ausente ou inválido.",
    )
    @SecurityRequirement(name = "bearerAuth")
    @ApiResponses(
        ApiResponse(
            responseCode = "200",
            description = "Sessão viva; retorna a pessoa sem qualquer material de senha.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = PersonResponse::class))],
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
    fun me(@Parameter(hidden = true) actor: AuthenticatedActor): HttpResponse<*>

    @Operation(
        operationId = "updateName",
        summary = "Atualiza o nome da pessoa autenticada",
        description = "Altera **apenas** o nome da pessoa dona da sessão viva e retorna sua visão pública " +
            "atualizada (id, nome, e-mail). E-mail, senha e status permanecem intocados. A rota é protegida: " +
            "sem um `Authorization: Bearer` válido o guard de borda recusa com o `401` neutro compartilhado, " +
            "antes do handler. Uma sessão órfã (pessoa não mais ativa) colapsa no mesmo `401`, indistinguível " +
            "de um token ausente ou inválido. Um nome que a borda aceita mas o domínio rejeita responde `422`.",
    )
    @SecurityRequirement(name = "bearerAuth")
    @ApiResponses(
        ApiResponse(
            responseCode = "200",
            description = "Nome atualizado; retorna a pessoa sem qualquer material de senha.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = PersonResponse::class))],
        ),
        ApiResponse(
            responseCode = "400",
            description = "Corpo ausente/inválido ou nome que viola as restrições de borda (presença, tamanho).",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
        ApiResponse(
            responseCode = "401",
            description = "Autenticação necessária; resposta neutra que não distingue token ausente/inválido de sessão órfã.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
        ApiResponse(
            responseCode = "422",
            description = "Nome bem-formado, porém rejeitado pela invariante de domínio.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
        ApiResponse(
            responseCode = "500",
            description = "Falha inesperada; a resposta é neutra e não vaza detalhes internos.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
    )
    fun updateName(
        @Parameter(hidden = true) actor: AuthenticatedActor,
        @Body @Valid request: UpdateNameRequest,
    ): HttpResponse<*>

    @Operation(
        operationId = "updateEmail",
        summary = "Troca o e-mail da pessoa autenticada",
        description = "Altera **apenas** o e-mail da pessoa dona da sessão viva, mediante confirmação da " +
            "**senha atual** (operação de step-up), e retorna sua visão pública atualizada (id, nome, e-mail). " +
            "Nome, senha e status permanecem intocados. A rota é protegida: sem um `Authorization: Bearer` " +
            "válido o guard de borda recusa com o `401` neutro compartilhado, antes do handler. Uma senha de " +
            "confirmação incorreta e uma sessão órfã (pessoa não mais ativa) colapsam no mesmo `401`, " +
            "indistinguível de um token ausente ou inválido. Um e-mail que a borda aceita mas o domínio " +
            "rejeita responde `422`; um e-mail já em uso por outra pessoa também responde `422`, com um corpo " +
            "genérico que não revela que o e-mail está cadastrado.",
    )
    @SecurityRequirement(name = "bearerAuth")
    @ApiResponses(
        ApiResponse(
            responseCode = "200",
            description = "E-mail atualizado; retorna a pessoa sem qualquer material de senha.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = PersonResponse::class))],
        ),
        ApiResponse(
            responseCode = "400",
            description = "Corpo ausente/inválido, e-mail que viola o formato de borda, ou senha ausente.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
        ApiResponse(
            responseCode = "401",
            description = "Autenticação necessária; resposta neutra que não distingue token ausente/inválido, senha de confirmação incorreta e sessão órfã.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
        ApiResponse(
            responseCode = "422",
            description = "E-mail bem-formado, porém rejeitado pela invariante de domínio, ou já em uso por outra pessoa (corpo genérico, sem vazar a existência da conta).",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
        ApiResponse(
            responseCode = "500",
            description = "Falha inesperada; a resposta é neutra e não vaza detalhes internos.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
    )
    fun updateEmail(
        @Parameter(hidden = true) actor: AuthenticatedActor,
        @Body @Valid request: UpdateEmailRequest,
    ): HttpResponse<*>
}
