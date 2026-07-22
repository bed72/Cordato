package com.bed.cordato.features.identity.infrastructure.http.controllers.docs

import jakarta.validation.Valid

import io.micronaut.http.MediaType
import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Body

import io.swagger.v3.oas.annotations.tags.Tag
import io.swagger.v3.oas.annotations.Parameter
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.media.Schema
import io.swagger.v3.oas.annotations.media.Content
import io.swagger.v3.oas.annotations.media.ExampleObject
import io.swagger.v3.oas.annotations.responses.ApiResponse
import io.swagger.v3.oas.annotations.responses.ApiResponses
import io.swagger.v3.oas.annotations.security.SecurityRequirement

import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse
import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor

import com.bed.cordato.features.identity.infrastructure.http.requests.UpdateNameRequest
import com.bed.cordato.features.identity.infrastructure.http.requests.UpdateEmailRequest
import com.bed.cordato.features.identity.infrastructure.http.requests.UpdatePasswordRequest

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
private const val INTERNAL_500 =
    """{"errors":[{"status":"500","code":"INTERNAL_ERROR","message":"Ocorreu um erro inesperado. Tente novamente mais tarde."}]}"""

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
            description = "Sessão viva; `data` (`PersonResponse`) traz a pessoa sem qualquer material de senha.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = PersonDataResponse::class))],
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
            description = "Nome atualizado; `data` (`PersonResponse`) traz a pessoa sem qualquer material de senha.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = PersonDataResponse::class))],
        ),
        ApiResponse(
            responseCode = "400",
            description = "Corpo ausente/inválido ou nome que viola as restrições de borda (presença, tamanho).",
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
            description = "Nome bem-formado, porém rejeitado pela invariante de domínio.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [
                        ExampleObject(
                            value = """{"errors":[{"status":"422","code":"INVALID_NAME","message":"O nome informado é inválido."}]}""",
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
            description = "E-mail atualizado; `data` (`PersonResponse`) traz a pessoa sem qualquer material de senha.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = PersonDataResponse::class))],
        ),
        ApiResponse(
            responseCode = "400",
            description = "Corpo ausente/inválido, e-mail que viola o formato de borda, ou senha ausente.",
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
            description = "Autenticação necessária; resposta neutra que não distingue token ausente/inválido, senha de confirmação incorreta e sessão órfã.",
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
            description = "E-mail bem-formado, porém rejeitado pela invariante de domínio, ou já em uso por outra pessoa (corpo genérico, sem vazar a existência da conta).",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [
                        ExampleObject(
                            name = "invalid_email",
                            summary = "E-mail inválido",
                            value = """{"errors":[{"status":"422","code":"INVALID_EMAIL","message":"O e-mail informado é inválido."}]}""",
                        ),
                        ExampleObject(
                            name = "email_already_in_use",
                            summary = "E-mail já em uso (resposta genérica)",
                            value = """{"errors":[{"status":"422","code":"EMAIL_UPDATE_REJECTED","message":"Não foi possível atualizar o e-mail."}]}""",
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
    fun updateEmail(
        @Parameter(hidden = true) actor: AuthenticatedActor,
        @Body @Valid request: UpdateEmailRequest,
    ): HttpResponse<*>

    @Operation(
        operationId = "updatePassword",
        summary = "Troca a senha da pessoa autenticada",
        description = "Rotaciona **apenas** a senha da pessoa dona da sessão viva, mediante confirmação da " +
            "**senha atual** (operação de step-up), e retorna sua visão pública (id, nome, e-mail) — a visão " +
            "não muda numa troca de senha, mas a forma é uniforme. Nome, e-mail e status permanecem intocados. " +
            "Ao trocar, **todas as demais sessões vivas da pessoa são encerradas** e a sessão que fez a troca " +
            "permanece válida. A rota é protegida: sem um `Authorization: Bearer` válido o guard de borda " +
            "recusa com o `401` neutro compartilhado, antes do handler. Uma senha de confirmação incorreta e " +
            "uma sessão órfã (pessoa não mais ativa) colapsam no mesmo `401`, indistinguível de um token " +
            "ausente ou inválido. Uma nova senha fraca (política pública) ou igual à atual responde `422`.",
    )
    @SecurityRequirement(name = "bearerAuth")
    @ApiResponses(
        ApiResponse(
            responseCode = "200",
            description = "Senha trocada; `data` (`PersonResponse`) traz a pessoa sem qualquer material de senha.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = PersonDataResponse::class))],
        ),
        ApiResponse(
            responseCode = "400",
            description = "Corpo ausente/inválido, senha atual ausente, ou nova senha ausente/abaixo do tamanho mínimo.",
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
            description = "Autenticação necessária; resposta neutra que não distingue token ausente/inválido, senha de confirmação incorreta e sessão órfã.",
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
            description = "Nova senha fraca (viola a política mínima, regra pública) ou igual à atual; ambas compartilham o `422`, então o status não delata qual ocorreu.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [
                        ExampleObject(
                            name = "weak_password",
                            summary = "Nova senha abaixo do mínimo público",
                            value = """{"errors":[{"status":"422","code":"WEAK_PASSWORD","message":"A senha deve ter ao menos 8 caracteres."}]}""",
                        ),
                        ExampleObject(
                            name = "same_password",
                            summary = "Nova senha igual à atual",
                            value = """{"errors":[{"status":"422","code":"SAME_PASSWORD","message":"A nova senha deve ser diferente da senha atual."}]}""",
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
    fun updatePassword(
        @Parameter(hidden = true) actor: AuthenticatedActor,
        @Body @Valid request: UpdatePasswordRequest,
    ): HttpResponse<*>
}
