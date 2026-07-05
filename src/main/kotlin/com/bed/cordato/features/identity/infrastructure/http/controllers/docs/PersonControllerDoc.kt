package com.bed.cordato.features.identity.infrastructure.http.controllers.docs

import com.bed.cordato.features.identity.infrastructure.http.requests.SignUpRequest
import com.bed.cordato.features.identity.infrastructure.http.responses.PersonResponse
import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse
import io.micronaut.http.HttpResponse
import io.micronaut.http.MediaType
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.media.Content
import io.swagger.v3.oas.annotations.media.Schema
import io.swagger.v3.oas.annotations.responses.ApiResponse
import io.swagger.v3.oas.annotations.responses.ApiResponses
import io.swagger.v3.oas.annotations.tags.Tag

/**
 * OpenAPI documentation for identity's HTTP routes, kept off the controller so the controller stays a
 * thin routing/validation adapter. Micronaut inherits an interface's annotation metadata onto the
 * implementing method, so the micronaut-openapi processor picks up the `@Operation`/`@ApiResponse`
 * declared here when it documents the route the controller registers with `@Post`.
 *
 * This is a **documentation artefact of the infrastructure layer**, not an application port: it does not
 * introduce a driving-side application contract nor duplicate the use case's public signature. The
 * controller's own `@Post`/`@Body`/`@Valid` (routing/validation) live on the implementation; only the
 * description of the operation and its responses live here. Each new context's controller follows the
 * same `<Controller>Doc` split.
 */
@Tag(name = "Identity", description = "Cadastro e autenticação de pessoas.")
interface PersonControllerDoc {

    @Operation(
        operationId = "signUp",
        summary = "Cadastra uma nova pessoa",
        description = "Registra uma pessoa a partir de nome, e-mail e senha. As respostas de erro seguem o " +
            "contrato compartilhado (código estável + mensagem localizável); um conflito de e-mail é " +
            "deliberadamente genérico e nunca confirma que o e-mail já está cadastrado.",
    )
    @ApiResponses(
        ApiResponse(
            responseCode = "201",
            description = "Pessoa cadastrada; retorna o recurso sem qualquer material de senha.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = PersonResponse::class))],
        ),
        ApiResponse(
            responseCode = "400",
            description = "Requisição malformada ou reprovada na validação de borda.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
        ApiResponse(
            responseCode = "422",
            description = "Requisição bem-formada recusada pelo domínio (nome/e-mail inválido, senha fraca, cadastro não concluído).",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
        ApiResponse(
            responseCode = "500",
            description = "Falha inesperada; a resposta é neutra e não vaza detalhes internos.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = ErrorResponse::class))],
        ),
    )
    fun signUp(request: SignUpRequest): HttpResponse<*>
}