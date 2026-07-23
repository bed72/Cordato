package com.bed.cordato.features.budget.infrastructure.http.mappers.responses

import com.bed.cordato.features.budget.infrastructure.http.responses.DefaultBudgetResponse

/** Projects the derived default-budget total into its public [DefaultBudgetResponse], as an `internal` extension. */
internal fun Long.toDefaultBudgetResponse(): DefaultBudgetResponse = DefaultBudgetResponse(spentInCents = this)
