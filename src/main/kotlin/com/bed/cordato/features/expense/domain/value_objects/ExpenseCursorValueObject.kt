package com.bed.cordato.features.expense.domain.value_objects

import java.time.LocalDate

/**
 * A keyset pagination position: the `(spent_on, id)` pair of the last item of a page, after which the next
 * page continues. This is exactly the deterministic ordering tuple the listing already sorts by — the
 * cursor is a name for "where I stopped", not a new concept.
 *
 * Carries two fields, so unlike [com.bed.cordato.core.domain.value_objects.MoneyValueObject] it is a plain
 * `data class`, not a `@JvmInline value class`. Construct via [of]; both fields are already valid by
 * construction ([spentOn] a real calendar day, [id] a stored expense's own id), so there is no intrinsic
 * rule to reject here. The **opaque wire encoding** (base64) of this position is an HTTP mapper's concern,
 * not this value object's.
 */
data class ExpenseCursorValueObject private constructor(
    val spentOn: LocalDate,
    val id: String,
) {
    companion object {
        fun of(spentOn: LocalDate, id: String): ExpenseCursorValueObject = ExpenseCursorValueObject(spentOn, id)
    }
}
