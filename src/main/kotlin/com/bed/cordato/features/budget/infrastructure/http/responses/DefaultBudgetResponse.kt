package com.bed.cordato.features.budget.infrastructure.http.responses

import io.micronaut.serde.annotation.Serdeable
import io.swagger.v3.oas.annotations.media.Schema

/**
 * The public view of the default budget ("no budget"), returned on `GET /budgets/default`. There is no
 * real budget behind this view — it's a fabricated grouping that always "exists" — so unlike
 * [BudgetResponse]/[ActiveBudgetResponse] it carries no `id`/`amountInCents`/`note`, only the derived
 * total.
 */
@Serdeable
@Schema(description = "Visão pública do orçamento padrão — o gasto somado fora de qualquer orçamento vivo, recalculado a cada leitura.")
data class DefaultBudgetResponse(
    @field:Schema(description = "Gasto somado fora de qualquer orçamento vivo, em centavos (inteiro), recalculado a cada leitura.", example = "12500")
    val spentInCents: Long,
)
