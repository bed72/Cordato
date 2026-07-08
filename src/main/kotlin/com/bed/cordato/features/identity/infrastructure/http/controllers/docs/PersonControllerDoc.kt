package com.bed.cordato.features.identity.infrastructure.http.controllers.docs

import io.micronaut.http.HttpResponse
import io.micronaut.http.MediaType

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
}
