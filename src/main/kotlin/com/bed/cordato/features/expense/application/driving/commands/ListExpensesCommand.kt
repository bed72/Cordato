package com.bed.cordato.features.expense.application.driving.commands

/**
 * The list-own-expenses request as it enters the application. [personId] is the owner whose expenses are
 * listed, supplied by the edge from the authenticated actor — **never** from a parameter, filter or body — so
 * a person can only ever list their own. It carries only the owner today; if filtering (date range, paging)
 * is added later, the command grows while the result stays a list.
 */
data class ListExpensesCommand(
    val personId: String,
)
