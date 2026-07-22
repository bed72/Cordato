package com.bed.cordato.features.identity.infrastructure.http.controllers.docs

import io.swagger.v3.oas.annotations.media.Schema

import com.bed.cordato.core.infrastructure.http.responses.MetaResponse
import com.bed.cordato.core.infrastructure.http.responses.LinksResponse
import com.bed.cordato.features.identity.infrastructure.http.responses.PersonResponse

/**
 * Documentation-only shape of [com.bed.cordato.core.infrastructure.http.responses.DataResponse] with `data`
 * fixed to [PersonResponse] — see [SignInDataResponse] for why this sibling exists instead of letting
 * micronaut-openapi resolve the erased generic. Shared by every operation whose `data` is the person's
 * public view (`me`, `updateName`, `updateEmail`, `updatePassword`, `signUp`). Never constructed or
 * returned at runtime.
 */
@Schema(description = "Envelope de sucesso com a visão pública da pessoa.")
data class PersonDataResponse(
    val data: PersonResponse,
    val meta: MetaResponse? = null,
    val links: LinksResponse? = null,
)
