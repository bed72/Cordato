package com.bed.cordato.features.budget.infrastructure.http.controllers.docs

import io.swagger.v3.oas.annotations.media.Schema

import com.bed.cordato.core.infrastructure.http.responses.MetaResponse
import com.bed.cordato.core.infrastructure.http.responses.LinksResponse
import com.bed.cordato.features.budget.infrastructure.http.responses.DefaultBudgetResponse

/**
 * Documentation-only shape of [com.bed.cordato.core.infrastructure.http.responses.DataResponse] with `data`
 * fixed to [DefaultBudgetResponse] — see identity's `SignInDataResponse` for why this sibling exists instead
 * of letting micronaut-openapi resolve the erased generic. Unlike [ActiveBudgetDataResponse], `data` is
 * always present here: the default budget is a fabricated grouping that always "exists". Never constructed
 * or returned at runtime.
 */
@Schema(description = "Envelope de sucesso com o orçamento padrão (gasto fora de orçamento), sempre presente.")
data class DefaultBudgetDataResponse(
    val data: DefaultBudgetResponse,
    val meta: MetaResponse? = null,
    val links: LinksResponse? = null,
)
