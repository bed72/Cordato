package com.bed.cordato.features.budget.infrastructure.http.controllers.docs

import io.swagger.v3.oas.annotations.media.Schema

import com.bed.cordato.core.infrastructure.http.responses.MetaResponse
import com.bed.cordato.core.infrastructure.http.responses.LinksResponse
import com.bed.cordato.features.budget.infrastructure.http.responses.BudgetResponse

/**
 * Documentation-only shape of [com.bed.cordato.core.infrastructure.http.responses.DataResponse] with `data`
 * fixed to [BudgetResponse] — see identity's `SignInDataResponse` for why this sibling exists instead of
 * letting micronaut-openapi resolve the erased generic. Never constructed or returned at runtime.
 */
@Schema(description = "Envelope de sucesso com a visão pública do orçamento criado.")
data class BudgetDataResponse(
    val data: BudgetResponse,
    val meta: MetaResponse? = null,
    val links: LinksResponse? = null,
)
