package com.bed.cordato.features.budget.application.driving.use_cases

import com.bed.cordato.core.domain.value_objects.MoneyValueObject

import com.bed.cordato.features.budget.domain.entities.BudgetEntity
import com.bed.cordato.features.budget.domain.enums.BudgetStatusEnum
import com.bed.cordato.features.budget.domain.errors.UpdateBudgetError
import com.bed.cordato.features.budget.domain.value_objects.NoteValueObject
import com.bed.cordato.features.budget.domain.value_objects.BudgetPeriodValueObject

import com.bed.cordato.features.budget.application.driving.results.UpdateBudgetResult
import com.bed.cordato.features.budget.application.driving.commands.UpdateBudgetCommand
import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository

/**
 * Edits a live budget of the authenticated actor. Order is deliberate (fail-fast), mirroring
 * [CreateBudgetUseCase] for the first three steps and identity's `UpdateEmailUseCase` for resolving the
 * resource only after the cheap, no-datastore validations already passed:
 *
 * 1. **Amount** — [MoneyValueObject.of] rejects a non-positive value as [UpdateBudgetError.InvalidAmount].
 * 2. **Period** — [BudgetPeriodValueObject.of] rejects an end before the start as
 *    [UpdateBudgetError.InvalidPeriod].
 * 3. **Note** — a null/blank raw is treated as **absent** before validating; only a present note that
 *    exceeds the maximum is [UpdateBudgetError.InvalidNote].
 * 4. **Resource** — [BudgetRepository.findById] resolves the budget; a `null` result, a different owner, or
 *    a non-live status all collapse into the same [UpdateBudgetError.BudgetNotFound] — indistinguishable
 *    from the outside (ADR 0008-style non-leak).
 * 5. **Overlap** — [BudgetRepository.hasOverlappingLiveBudget], excluding the budget being edited, rejects a
 *    period that shares a day (inclusive of boundaries) with another live budget of the same person as
 *    [UpdateBudgetError.OverlappingBudget].
 *
 * Then it builds the updated [BudgetEntity] (same `id`/`personId`/`status`, new `amount`/`period`/`note`)
 * and persists it. `command.personId` comes from the authenticated actor, never the body, so the owner
 * never changes even if the command tried.
 *
 * The public `invoke` signature is the driving (primary) side of this context.
 */
class UpdateBudgetUseCase(
    private val repository: BudgetRepository,
) {
    operator fun invoke(command: UpdateBudgetCommand): UpdateBudgetResult {
        val amount = MoneyValueObject.of(command.amountInCents)
            ?: return UpdateBudgetResult.Failure(UpdateBudgetError.InvalidAmount)

        val period = BudgetPeriodValueObject.of(command.startDate, command.endDate)
            ?: return UpdateBudgetResult.Failure(UpdateBudgetError.InvalidPeriod)

        val note = command.note?.takeIf { it.isNotBlank() }?.let { raw ->
            NoteValueObject.of(raw) ?: return UpdateBudgetResult.Failure(UpdateBudgetError.InvalidNote)
        }

        val existing = repository.findById(command.budgetId)
            ?.takeIf { it.personId == command.personId && it.status == BudgetStatusEnum.LIVE }
            ?: return UpdateBudgetResult.Failure(UpdateBudgetError.BudgetNotFound)

        if (repository.hasOverlappingLiveBudget(command.personId, period.startDate, period.endDate, excludeId = command.budgetId)) {
            return UpdateBudgetResult.Failure(UpdateBudgetError.OverlappingBudget)
        }

        val budget = existing.copy(note = note, amount = amount, period = period)
        repository.update(budget)

        return UpdateBudgetResult.Success(budget)
    }
}
