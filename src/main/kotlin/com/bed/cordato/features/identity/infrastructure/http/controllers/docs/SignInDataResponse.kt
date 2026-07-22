package com.bed.cordato.features.identity.infrastructure.http.controllers.docs

import io.swagger.v3.oas.annotations.media.Schema

import com.bed.cordato.core.infrastructure.http.responses.MetaResponse
import com.bed.cordato.core.infrastructure.http.responses.LinksResponse
import com.bed.cordato.features.identity.infrastructure.http.responses.SignInResponse

/**
 * Documentation-only shape of [com.bed.cordato.core.infrastructure.http.responses.DataResponse] with `data`
 * fixed to [SignInResponse] — the micronaut-openapi processor cannot resolve `DataResponse<T>`'s generic
 * parameter through the controller's actual `HttpResponse<*>` return type, so every operation's `@Schema`
 * would otherwise collapse onto the same erased, shapeless `data: object`. This type is never constructed or
 * returned at runtime; it exists solely so `signIn`'s `@ApiResponse` can point `@Schema(implementation = ...)`
 * at a concrete, correctly-shaped envelope. Apply the same per-operation sibling wherever `data`'s real type
 * needs to show up in Swagger.
 */
@Schema(description = "Envelope de sucesso do login. `data` traz o token opaco e sua expiração.")
data class SignInDataResponse(
    val data: SignInResponse,
    val meta: MetaResponse? = null,
    val links: LinksResponse? = null,
)
