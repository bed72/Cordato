package com.bed.cordato.features.budget.infrastructure.http.responses

import java.time.LocalDate
import io.micronaut.serde.annotation.Serdeable
import io.swagger.v3.oas.annotations.media.Schema

/**
 * The public view of the active budget, returned on `GET /budgets/active`. Carries the raw ceiling plus the
 * two derived amounts, flat — no VO/nesting at the edge, mirroring [BudgetResponse]'s style. Both derived
 * amounts stay integer cents on the wire, exact end to end; [remainingInCents] may be negative when the
 * budget is exceeded.
 */
@Serdeable
@Schema(description = "Visão pública do orçamento ativo — orçamento vivo de hoje, gasto somado e restante, ambos derivados a cada leitura.")
data class ActiveBudgetResponse(
    @field:Schema(description = "Identificador único do orçamento.", example = "018f9e2a-7b3c-7c4d-9e2a-1b2c3d4e5f60")
    val id: String,
    @field:Schema(description = "Valor do orçamento em centavos (inteiro).", example = "100000")
    val amountInCents: Long,
    @field:Schema(description = "Gasto somado do intervalo do orçamento, em centavos (inteiro), recalculado a cada leitura.", example = "45000")
    val spentInCents: Long,
    @field:Schema(description = "Valor restante em centavos (inteiro); pode ser negativo quando o orçamento está estourado.", example = "55000")
    val remainingInCents: Long,
    @field:Schema(description = "Data de início do orçamento, incluída.", example = "2026-07-01")
    val startDate: LocalDate,
    @field:Schema(description = "Data de fim do orçamento, incluída.", example = "2026-07-31")
    val endDate: LocalDate,
    @field:Schema(description = "Anotação do orçamento, quando houver.", example = "Viagem de férias")
    val note: String?,
)
