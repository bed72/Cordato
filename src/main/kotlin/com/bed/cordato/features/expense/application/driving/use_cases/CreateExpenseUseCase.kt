package com.bed.cordato.features.expense.application.driving.use_cases

import java.time.LocalDate
import java.time.ZoneOffset

import com.bed.cordato.core.domain.value_objects.MoneyValueObject

import com.bed.cordato.core.application.driven.ports.ClockPort
import com.bed.cordato.core.application.driven.ports.IdGeneratorPort

import com.bed.cordato.features.expense.domain.errors.CreateExpenseError
import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.domain.value_objects.ExpenseDateValueObject
import com.bed.cordato.features.expense.domain.value_objects.DescriptionValueObject

import com.bed.cordato.features.expense.application.driving.results.CreateExpenseResult
import com.bed.cordato.features.expense.application.driving.commands.CreateExpenseCommand
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Registers a new expense for the authenticated actor. Order is deliberate (fail-fast):
 *
 * 1. **Amount** — [MoneyValueObject.of] rejects a non-positive value as [CreateExpenseError.InvalidAmount].
 * 2. **Date** — absent ⇒ today (derived from the [ClockPort] at [ZoneOffset.UTC], the single place the
 *    "today" timezone is decided until a user timezone exists); a given date after today is
 *    [CreateExpenseError.FutureDate]. The "not future" rule needs the clock, so it lives here, not in the
 *    pure value object.
 * 3. **Description** — a null/blank raw is treated as **absent** (no description) *before* validating; only a
 *    present description that exceeds the maximum is [CreateExpenseError.InvalidDescription], so "absent" and
 *    "too long" never collapse together.
 *
 * Then it builds the [ExpenseEntity] with a fresh id from the [IdGeneratorPort] and persists it. The owner is
 * `command.personId` — resolved by the edge from the authenticated actor, never the body — so a person can
 * only ever register their own expense. The expense carries no budget reference by construction.
 *
 * The public `invoke` signature is the driving (primary) side of this context.
 */
class CreateExpenseUseCase(
    private val clock: ClockPort,
    private val generator: IdGeneratorPort,
    private val repository: ExpenseRepository,
) {
    operator fun invoke(command: CreateExpenseCommand): CreateExpenseResult {
        val amount = MoneyValueObject.of(command.amountInCents)
            ?: return CreateExpenseResult.Failure(CreateExpenseError.InvalidAmount)

        val today = LocalDate.ofInstant(clock(), ZoneOffset.UTC)
        val day = command.date ?: today
        if (day.isAfter(today)) return CreateExpenseResult.Failure(CreateExpenseError.FutureDate)
        val date = ExpenseDateValueObject.of(day)

        val description = command.description?.takeIf { it.isNotBlank() }?.let { raw ->
            DescriptionValueObject.of(raw)
                ?: return CreateExpenseResult.Failure(CreateExpenseError.InvalidDescription)
        }

        val expense = ExpenseEntity(
            date = date,
            amount = amount,
            id = generator(),
            description = description,
            personId = command.personId,
        )
        repository.create(expense)

        return CreateExpenseResult.Success(expense)
    }
}
