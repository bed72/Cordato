package com.bed.cordato.features.expense.infrastructure.http.requests

import java.time.LocalDate

import jakarta.validation.constraints.Size
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Positive

import io.micronaut.serde.annotation.Serdeable
import io.swagger.v3.oas.annotations.media.Schema

import com.bed.cordato.features.expense.domain.value_objects.DescriptionValueObject

/**
 * Body of `POST /expenses` as it arrives over HTTP, validated at the edge (Bean Validation) before the use
 * case runs. The owner is **not** here — it comes from the authenticated actor, never the body.
 *
 * `amountInCents` is required (`@NotNull`) and mirrors the money rule with `@Positive` — the semantic ">
 * 0" [com.bed.cordato.core.domain.value_objects.MoneyValueObject] enforces, expressed with no copied literal
 * so the edge can't drift. `description` references the value object's own [DescriptionValueObject.MAX_LENGTH]
 * bound, never a literal. `date` is transport-only (an optional [LocalDate], no value object): a
 * syntactically bad date is a `400 MALFORMED_REQUEST` from the parser, while "not in the future" is a domain
 * rule enforced in the use case (a `422`), so it carries no edge constraint. The value objects stay the
 * single authority; these annotations are an earlier, deliberately-equal-or-stricter guard.
 *
 * Each constraint's `message` is a `{key}` into the shared message bundle, not inline text — one origin for
 * every response text, localizable per `Accept-Language`; the `{max}` bound is re-interpolated from the
 * referenced constant.
 */
@Serdeable
@Schema(description = "Dados para registrar um novo gasto.")
data class CreateExpenseRequest(
    @field:Schema(
        example = "1500",
        description = "Valor do gasto em centavos (inteiro), sempre maior que zero.",
    )
    @field:NotNull(message = "{createExpense.request.amountInCents.notNull}")
    @field:Positive(message = "{createExpense.request.amountInCents.positive}")
    val amountInCents: Long?,

    @field:Schema(
        example = "2026-07-10",
        description = "Data em que o gasto aconteceu (YYYY-MM-DD). Opcional: ausente assume hoje; nunca no futuro.",
    )
    val date: LocalDate?,

    @field:Schema(
        example = "Almoço",
        description = "Descrição opcional do gasto. É aparada (trim); não pode exceder o comprimento máximo.",
    )
    @field:Size(max = DescriptionValueObject.MAX_LENGTH, message = "{createExpense.request.description.maxSize}")
    val description: String?,
)
