package com.bed.cordato.features.budget.infrastructure.http.responses

import java.time.LocalDate
import io.micronaut.serde.annotation.Serdeable
import io.swagger.v3.oas.annotations.media.Schema

/**
 * The public view of a created budget, returned on a successful `POST /budgets`. Carries only the raw
 * ceiling — id, exact amount in cents, the covered date range, and the optional note; there is deliberately
 * no expense reference nor any derived value (spent/remaining), mirroring the entity. The amount stays an
 * integer number of cents on the wire (never a decimal), so precision is exact end to end.
 */
@Serdeable
@Schema(description = "Visão pública de um orçamento criado.")
data class BudgetResponse(
    @field:Schema(description = "Identificador único do orçamento.", example = "018f9e2a-7b3c-7c4d-9e2a-1b2c3d4e5f60")
    val id: String,
    @field:Schema(description = "Valor do orçamento em centavos (inteiro).", example = "100000")
    val amountInCents: Long,
    @field:Schema(description = "Data de início do orçamento, incluída.", example = "2026-07-01")
    val startDate: LocalDate,
    @field:Schema(description = "Data de fim do orçamento, incluída.", example = "2026-07-31")
    val endDate: LocalDate,
    @field:Schema(description = "Anotação do orçamento, quando houver.", example = "Viagem de férias")
    val note: String?,
)
