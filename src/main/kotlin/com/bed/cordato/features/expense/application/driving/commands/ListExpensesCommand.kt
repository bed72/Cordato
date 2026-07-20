package com.bed.cordato.features.expense.application.driving.commands

import com.bed.cordato.features.expense.domain.value_objects.ExpenseCursorValueObject

/**
 * The list-own-expenses request as it enters the application. [personId] is the owner whose expenses are
 * listed, supplied by the edge from the authenticated actor — **never** from a parameter, filter or body — so
 * a person can only ever list their own. [limit] is the page size and [after] the keyset position to
 * continue from (`null` for the first page); both already validated/decoded at the edge before the command
 * is built.
 */
data class ListExpensesCommand(
    val personId: String,
    val limit: Int,
    val after: ExpenseCursorValueObject?,
)
