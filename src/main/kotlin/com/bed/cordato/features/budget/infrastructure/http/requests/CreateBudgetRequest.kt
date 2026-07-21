package com.bed.cordato.features.budget.infrastructure.http.requests

import java.time.LocalDate

import jakarta.validation.constraints.Size
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Positive

import io.micronaut.serde.annotation.Serdeable
import io.swagger.v3.oas.annotations.media.Schema

import com.bed.cordato.features.budget.domain.value_objects.NoteValueObject

/**
 * Body of `POST /budgets` as it arrives over HTTP, validated at the edge (Bean Validation) before the use
 * case runs. The owner is **not** here — it comes from the authenticated actor, never the body.
 *
 * `amountInCents` is required (`@NotNull`) and mirrors the money rule with `@Positive` — the semantic ">
 * 0" [com.bed.cordato.core.domain.value_objects.MoneyValueObject] enforces, expressed with no copied
 * literal so the edge can't drift. `startDate`/`endDate` are both required, transport-only (`LocalDate`, no
 * value object): a syntactically bad date is a `400 MALFORMED_REQUEST` from the parser, while "end not
 * before start" is a domain rule enforced in the use case (a `422`), so it carries no edge constraint.
 * `note` references [NoteValueObject.MAX_LENGTH], never a literal.
 *
 * Each constraint's `message` is a `{key}` into the shared message bundle, not inline text.
 */
@Serdeable
@Schema(description = "Dados para criar um novo orçamento.")
data class CreateBudgetRequest(
    @field:Schema(
        example = "100000",
        description = "Valor do orçamento em centavos (inteiro), sempre maior que zero.",
    )
    @field:NotNull(message = "{createBudget.request.amountInCents.notNull}")
    @field:Positive(message = "{createBudget.request.amountInCents.positive}")
    val amountInCents: Long?,

    @field:Schema(example = "2026-07-01", description = "Data de início do orçamento (YYYY-MM-DD), incluída.")
    @field:NotNull(message = "{createBudget.request.startDate.notNull}")
    val startDate: LocalDate?,

    @field:Schema(
        example = "2026-07-31",
        description = "Data de fim do orçamento (YYYY-MM-DD), incluída. Nunca anterior à data de início.",
    )
    @field:NotNull(message = "{createBudget.request.endDate.notNull}")
    val endDate: LocalDate?,

    @field:Schema(
        example = "Viagem de férias",
        description = "Anotação opcional do orçamento. É aparada (trim); não pode exceder o comprimento máximo.",
    )
    @field:Size(max = NoteValueObject.MAX_LENGTH, message = "{createBudget.request.note.maxSize}")
    val note: String?,
)
