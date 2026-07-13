package com.bed.cordato.features.expense.application.driving.commands

/**
 * Input to list one's own expenses. [personId] is the owner whose expenses are listed, supplied by the edge
 * from the authenticated actor — **never** from a request parameter, filter or body, so a person can only
 * ever list their own expenses. The command carries only the owner today; if filters (date range, paging)
 * arrive later they grow it, while the use case's return stays a list.
 */
data class ListExpensesCommand(
    val personId: String,
)
