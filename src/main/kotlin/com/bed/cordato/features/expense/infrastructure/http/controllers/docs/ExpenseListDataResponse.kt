package com.bed.cordato.features.expense.infrastructure.http.controllers.docs

import io.swagger.v3.oas.annotations.media.Schema

import com.bed.cordato.core.infrastructure.http.responses.MetaResponse
import com.bed.cordato.core.infrastructure.http.responses.LinksResponse
import com.bed.cordato.features.expense.infrastructure.http.responses.ExpenseResponse

/**
 * Documentation-only shape of [com.bed.cordato.core.infrastructure.http.responses.DataResponse] with `data`
 * fixed to a list of [ExpenseResponse] — see identity's `SignInDataResponse` for why this sibling exists
 * instead of letting micronaut-openapi resolve the erased generic. `meta.pagination.next_cursor`/`links.next`
 * are present only when there is a next page. Never constructed or returned at runtime.
 */
@Schema(description = "Envelope de sucesso com a página de gastos do ator autenticado.")
data class ExpenseListDataResponse(
    val data: List<ExpenseResponse>,
    val meta: MetaResponse? = null,
    val links: LinksResponse? = null,
)
