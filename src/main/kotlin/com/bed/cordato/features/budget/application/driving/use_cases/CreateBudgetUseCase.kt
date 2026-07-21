package com.bed.cordato.features.budget.application.driving.use_cases

import com.bed.cordato.core.domain.value_objects.MoneyValueObject

import com.bed.cordato.core.application.driven.ports.IdGeneratorPort

import com.bed.cordato.features.budget.domain.entities.BudgetEntity
import com.bed.cordato.features.budget.domain.enums.BudgetStatusEnum
import com.bed.cordato.features.budget.domain.errors.CreateBudgetError
import com.bed.cordato.features.budget.domain.value_objects.NoteValueObject
import com.bed.cordato.features.budget.domain.value_objects.BudgetPeriodValueObject

import com.bed.cordato.features.budget.application.driving.results.CreateBudgetResult
import com.bed.cordato.features.budget.application.driving.commands.CreateBudgetCommand
import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository

/**
 * Creates a new budget for the authenticated actor. Order is deliberate (fail-fast):
 *
 * 1. **Amount** — [MoneyValueObject.of] rejects a non-positive value as [CreateBudgetError.InvalidAmount].
 * 2. **Period** — [BudgetPeriodValueObject.of] rejects an end before the start as
 *    [CreateBudgetError.InvalidPeriod]. Both dates are always given; there is no "today" default here.
 * 3. **Note** — a null/blank raw is treated as **absent** (no note) *before* validating; only a present
 *    note that exceeds the maximum is [CreateBudgetError.InvalidNote], so "absent" and "too long" never
 *    collapse together.
 * 4. **Overlap** — [BudgetRepository.hasOverlappingLiveBudget] rejects a period that shares a day (inclusive
 *    of boundaries) with another live budget of the same person as [CreateBudgetError.OverlappingBudget].
 *
 * Then it builds the [BudgetEntity] with a fresh id from the [IdGeneratorPort] and status
 * [BudgetStatusEnum.LIVE], and persists it. The owner is `command.personId` — resolved by the edge from
 * the authenticated actor, never the body — so a person can only ever create their own budget. The budget
 * carries no expense reference by construction.
 *
 * The public `invoke` signature is the driving (primary) side of this context.
 */
class CreateBudgetUseCase(
    private val generator: IdGeneratorPort,
    private val repository: BudgetRepository,
) {
    operator fun invoke(command: CreateBudgetCommand): CreateBudgetResult {
        val amount = MoneyValueObject.of(command.amountInCents)
            ?: return CreateBudgetResult.Failure(CreateBudgetError.InvalidAmount)

        val period = BudgetPeriodValueObject.of(command.startDate, command.endDate)
            ?: return CreateBudgetResult.Failure(CreateBudgetError.InvalidPeriod)

        val note = command.note?.takeIf { it.isNotBlank() }?.let { raw ->
            NoteValueObject.of(raw) ?: return CreateBudgetResult.Failure(CreateBudgetError.InvalidNote)
        }

        if (repository.hasOverlappingLiveBudget(command.personId, period.startDate, period.endDate)) {
            return CreateBudgetResult.Failure(CreateBudgetError.OverlappingBudget)
        }

        val budget = BudgetEntity(
            note = note,
            amount = amount,
            period = period,
            id = generator(),
            personId = command.personId,
            status = BudgetStatusEnum.LIVE,
        )
        repository.create(budget)

        return CreateBudgetResult.Success(budget)
    }
}
