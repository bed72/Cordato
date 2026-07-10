package com.bed.cordato.features.expense.factories

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

import com.bed.cordato.core.factories.clockFixedAt
import com.bed.cordato.core.factories.idGeneratorOf

import com.bed.cordato.features.expense.application.driving.use_cases.CreateExpenseUseCase
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

/**
 * Fixed reference instant for expense use-case tests, and the UTC calendar day it falls on — the same zone
 * [CreateExpenseUseCase] derives "today" at, so a test can compare a default-dated expense against
 * [EXPENSE_TODAY]. Exported from the SUT builder's file (where the clock is wired) so both this and
 * [createExpenseCommand] share one origin.
 */
val EXPENSE_NOW: Instant = Instant.parse("2026-07-10T12:00:00Z")
val EXPENSE_TODAY: LocalDate = LocalDate.ofInstant(EXPENSE_NOW, ZoneOffset.UTC)

/**
 * Builds a [CreateExpenseUseCase] over a frozen clock and a deterministic id generator, mirroring identity's
 * `signUpUseCase` — the SUT builder lives in `factories/`, never as a private helper inside the test class.
 * The [repository] defaults to a fresh [FakeExpenseRepository]; a test that asserts what was persisted passes
 * its own instance.
 */
fun createExpenseUseCase(
    now: Instant = EXPENSE_NOW,
    id: String = "expense-1",
    repository: ExpenseRepository = FakeExpenseRepository(),
): CreateExpenseUseCase = CreateExpenseUseCase(clockFixedAt(now), idGeneratorOf(id), repository)
