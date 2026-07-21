package com.bed.cordato.features.budget.factories

import java.time.LocalDate

import com.bed.cordato.core.domain.value_objects.MoneyValueObject

import com.bed.cordato.features.budget.domain.entities.BudgetEntity
import com.bed.cordato.features.budget.domain.enums.BudgetStatusEnum
import com.bed.cordato.features.budget.domain.value_objects.NoteValueObject
import com.bed.cordato.features.budget.domain.value_objects.BudgetPeriodValueObject

/**
 * Builds a valid [BudgetEntity] from convenient primitives for tests, mirroring expense's `expense(...)`
 * builder — the raw inputs are turned into their value objects so a test states only what it cares about.
 */
fun budget(
    id: String = "budget-1",
    note: String? = "Viagem",
    personId: String = "person-1",
    amountInCents: Long = 100_000,
    status: BudgetStatusEnum = BudgetStatusEnum.LIVE,
    endDate: LocalDate = LocalDate.of(2026, 7, 31),
    startDate: LocalDate = LocalDate.of(2026, 7, 1),
): BudgetEntity = BudgetEntity(
    id = id,
    status = status,
    personId = personId,
    amount = MoneyValueObject.of(amountInCents)!!,
    note = note?.let { NoteValueObject.of(it)!! },
    period = BudgetPeriodValueObject.of(startDate, endDate)!!,
)
