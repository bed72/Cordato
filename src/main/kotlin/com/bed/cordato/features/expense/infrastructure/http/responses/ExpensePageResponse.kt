package com.bed.cordato.features.expense.infrastructure.http.responses

import io.micronaut.serde.annotation.Serdeable
import io.swagger.v3.oas.annotations.media.Schema

/**
 * The public envelope for a page of the authenticated actor's own expenses. [items] is the page's slice in
 * the public view (empty on a page with nothing); [nextCursor] is the opaque wire token for the next page,
 * or `null` exactly on the last page. Serialized as `next_cursor` on the wire (global snake_case policy).
 */
@Serdeable
@Schema(description = "Página de gastos do ator autenticado, paginada por cursor.")
data class ExpensePageResponse(
    @field:Schema(description = "Gastos da página, na visão pública.")
    val items: List<ExpenseResponse>,
    @field:Schema(
        nullable = true,
        example = "MjAyNi0wNy0xMHwwMThmOWUyYS03YjNjLTdjNGQtOWUyYS0xYjJjM2Q0ZTVmNjA",
        description = "Cursor opaco para a próxima página, ou ausente na última página.",
    )
    val nextCursor: String?,
)
