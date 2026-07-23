package com.bed.cordato.features.budget.infrastructure.http.requests

import java.time.LocalDate

import jakarta.validation.constraints.Size
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Positive

import io.micronaut.serde.annotation.Serdeable
import io.swagger.v3.oas.annotations.media.Schema

import com.bed.cordato.features.budget.domain.value_objects.NoteValueObject

/**
 * Body of `PATCH /budgets/{id}` as it arrives over HTTP, validated at the edge (Bean Validation) before the
 * use case runs — same fields/constraints as [CreateBudgetRequest] (this slice always reedits the three
 * mutable fields together, no partial edit of a single one). Neither the `id` (comes from the URL path) nor
 * the owner (comes from the authenticated actor) is here.
 *
 * Each constraint's `message` is a `{key}` into the shared message bundle, not inline text.
 */
@Serdeable
@Schema(description = "Dados para editar um orçamento existente.")
data class UpdateBudgetRequest(
    @field:Schema(
        example = "100000",
        description = "Valor do orçamento em centavos (inteiro), sempre maior que zero.",
    )
    @field:NotNull(message = "{updateBudget.request.amountInCents.notNull}")
    @field:Positive(message = "{updateBudget.request.amountInCents.positive}")
    val amountInCents: Long?,

    @field:Schema(example = "2026-07-01", description = "Data de início do orçamento (YYYY-MM-DD), incluída.")
    @field:NotNull(message = "{updateBudget.request.startDate.notNull}")
    val startDate: LocalDate?,

    @field:Schema(
        example = "2026-07-31",
        description = "Data de fim do orçamento (YYYY-MM-DD), incluída. Nunca anterior à data de início.",
    )
    @field:NotNull(message = "{updateBudget.request.endDate.notNull}")
    val endDate: LocalDate?,

    @field:Schema(
        example = "Viagem de férias",
        description = "Anotação opcional do orçamento. É aparada (trim); não pode exceder o comprimento máximo.",
    )
    @field:Size(max = NoteValueObject.MAX_LENGTH, message = "{updateBudget.request.note.maxSize}")
    val note: String?,
)
