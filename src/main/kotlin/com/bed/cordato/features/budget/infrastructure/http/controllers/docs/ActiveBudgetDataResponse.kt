package com.bed.cordato.features.budget.infrastructure.http.controllers.docs

import io.swagger.v3.oas.annotations.media.Schema

import com.bed.cordato.core.infrastructure.http.responses.MetaResponse
import com.bed.cordato.core.infrastructure.http.responses.LinksResponse
import com.bed.cordato.features.budget.infrastructure.http.responses.ActiveBudgetResponse

/**
 * Documentation-only shape of [com.bed.cordato.core.infrastructure.http.responses.DataResponse] with `data`
 * fixed to a nullable [ActiveBudgetResponse] — see identity's `SignInDataResponse` for why this sibling
 * exists instead of letting micronaut-openapi resolve the erased generic. `data` is nullable because the
 * absence of an active budget is a success, never an error. Never constructed or returned at runtime.
 */
@Schema(description = "Envelope de sucesso com o orçamento ativo, ou `data` nulo quando não há nenhum.")
data class ActiveBudgetDataResponse(
    @field:Schema(nullable = true)
    val data: ActiveBudgetResponse?,
    val meta: MetaResponse? = null,
    val links: LinksResponse? = null,
)
