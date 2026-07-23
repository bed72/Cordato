package com.bed.cordato.features.budget.application.driving.commands

/**
 * Raw remove-budget input as it arrives from the outside world. [budgetId] comes from the URL path,
 * [personId] from the authenticated actor, **never** from the request body — a person can only ever remove
 * their own budget.
 */
data class DeleteBudgetCommand(
    val budgetId: String,
    val personId: String,
)
