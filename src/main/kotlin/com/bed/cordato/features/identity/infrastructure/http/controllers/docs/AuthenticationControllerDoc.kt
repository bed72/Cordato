package com.bed.cordato.features.identity.infrastructure.http.controllers.docs

import io.micronaut.http.MediaType
import io.micronaut.http.HttpResponse

import io.swagger.v3.oas.annotations.tags.Tag
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.media.Schema
import io.swagger.v3.oas.annotations.media.Content
import io.swagger.v3.oas.annotations.media.ExampleObject
import io.swagger.v3.oas.annotations.responses.ApiResponse
import io.swagger.v3.oas.annotations.responses.ApiResponses

import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse
import com.bed.cordato.features.identity.infrastructure.http.requests.SignUpRequest
import com.bed.cordato.features.identity.infrastructure.http.requests.SignInRequest

/**
 * Real example payloads for the shared [ErrorsResponse] shape, one per status/code this controller's routes
 * actually emit — see [com.bed.cordato.core.infrastructure.http.responses.ErrorResponse] for the builders and
 * `i18n/messages.properties` for the exact resolved text. Without an explicit example, every response
 * referencing [ErrorsResponse] would render the same schema-level placeholder regardless of its real status,
 * which is misleading (a `401`/`500` showing a `422` payload).
 */
private const val MALFORMED_400 =
    """{"errors":[{"status":"400","code":"MALFORMED_REQUEST","message":"O corpo da requisição está ausente ou é inválido."}]}"""
private const val INTERNAL_500 =
    """{"errors":[{"status":"500","code":"INTERNAL_ERROR","message":"Ocorreu um erro inesperado. Tente novamente mais tarde."}]}"""

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
@Tag(name = "Authentication", description = "Cadastro e autenticação de pessoas.")
interface AuthenticationControllerDoc {

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
            description = "Pessoa cadastrada; `data` (`PersonResponse`) traz o recurso sem qualquer material de senha.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = PersonDataResponse::class))],
        ),
        ApiResponse(
            responseCode = "400",
            description = "Requisição malformada ou reprovada na validação de borda.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [ExampleObject(value = MALFORMED_400)],
                ),
            ],
        ),
        ApiResponse(
            responseCode = "422",
            description = "Requisição bem-formada recusada pelo domínio (nome/e-mail inválido, senha fraca, cadastro não concluído).",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [
                        ExampleObject(
                            name = "invalid_name",
                            summary = "Nome inválido",
                            value = """{"errors":[{"status":"422","code":"INVALID_NAME","message":"O nome informado é inválido."}]}""",
                        ),
                        ExampleObject(
                            name = "invalid_email",
                            summary = "E-mail inválido",
                            value = """{"errors":[{"status":"422","code":"INVALID_EMAIL","message":"O e-mail informado é inválido."}]}""",
                        ),
                        ExampleObject(
                            name = "email_already_in_use",
                            summary = "Cadastro não concluído (e-mail em uso, resposta genérica)",
                            value = """{"errors":[{"status":"422","code":"SIGNUP_REJECTED","message":"Não foi possível concluir o cadastro."}]}""",
                        ),
                        ExampleObject(
                            name = "weak_password",
                            summary = "Senha abaixo do mínimo público",
                            value = """{"errors":[{"status":"422","code":"WEAK_PASSWORD","message":"A senha deve ter ao menos 8 caracteres."}]}""",
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
    fun signUp(request: SignUpRequest): HttpResponse<*>

    @Operation(
        operationId = "signIn",
        summary = "Autentica uma pessoa",
        description = "Autentica por e-mail e senha e, em caso de sucesso, abre uma sessão retornando o token " +
            "opaco e sua expiração. A recusa é deliberadamente genérica: senha errada, e-mail desconhecido e " +
            "pessoa não ativa colapsam no mesmo `401`, sem revelar qual fator falhou nem se o e-mail existe.",
    )
    @ApiResponses(
        ApiResponse(
            responseCode = "200",
            description = "Autenticada; `data` (`SignInResponse`) traz o token opaco (uma única vez) e a expiração da sessão.",
            content = [Content(mediaType = MediaType.APPLICATION_JSON, schema = Schema(implementation = SignInDataResponse::class))],
        ),
        ApiResponse(
            responseCode = "400",
            description = "Requisição malformada ou sem os campos obrigatórios (validação de presença na borda).",
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
            description = "Credenciais inválidas; resposta neutra que não distingue qual fator falhou.",
            content = [
                Content(
                    mediaType = MediaType.APPLICATION_JSON,
                    schema = Schema(implementation = ErrorsResponse::class),
                    examples = [
                        ExampleObject(
                            value = """{"errors":[{"status":"401","code":"UNAUTHENTICATED","message":"E-mail ou senha inválidos."}]}""",
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
    fun signIn(request: SignInRequest): HttpResponse<*>
}
