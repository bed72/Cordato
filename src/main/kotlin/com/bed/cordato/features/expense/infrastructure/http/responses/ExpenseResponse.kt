package com.bed.cordato.features.expense.infrastructure.http.responses

import java.time.LocalDate
import io.micronaut.serde.annotation.Serdeable
import io.swagger.v3.oas.annotations.media.Schema

/**
 * The public view of a registered expense, returned on a successful `POST /expenses`. Carries only the raw
 * fact — id, exact amount in cents, the day it happened, and the optional description; there is deliberately
 * no budget reference, mirroring the entity. The amount stays an integer number of cents on the wire (never
 * a decimal), so precision is exact end to end; display formatting is the client's concern.
 */
@Serdeable
@Schema(description = "Visão pública de um gasto registrado.")
data class ExpenseResponse(
    @field:Schema(description = "Identificador único do gasto.", example = "018f9e2a-7b3c-7c4d-9e2a-1b2c3d4e5f60")
    val id: String,
    @field:Schema(description = "Valor do gasto em centavos (inteiro).", example = "1500")
    val amountInCents: Long,
    @field:Schema(description = "Data em que o gasto aconteceu.", example = "2026-07-10")
    val date: LocalDate,
    @field:Schema(description = "Descrição do gasto, quando houver.", example = "Almoço")
    val description: String?,
)
