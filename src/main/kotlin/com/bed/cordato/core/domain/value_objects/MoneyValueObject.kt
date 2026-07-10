package com.bed.cordato.core.domain.value_objects

/**
 * An exact money amount, held as an integer number of [cents] — never a `Double`, so the domain's
 * "exact value" invariant is a representation guarantee, not a discipline. BRL-only: there is no
 * currency abstraction, that complexity isn't needed here. Display formatting (`R$ 1.234,56`) is a
 * presentation concern, kept out of this type.
 *
 * Lives in `core` (the shared kernel — "exact money arithmetic") because every money-bearing context
 * needs it: `expense` registers the raw amount today, `budget` will reuse it for ceiling/spent/remaining.
 *
 * Construct via [of], which returns null when [cents] is not strictly positive — a zero or negative
 * amount is not a valid money value. [cents] is a `Long` (not `Int`) so future budget sums can't overflow.
 * The surface stays minimal (no arithmetic yet); addition/subtraction arrive when `budget` needs them.
 */
@JvmInline
value class MoneyValueObject private constructor(val cents: Long) {
    companion object {
        fun of(cents: Long): MoneyValueObject? = if (cents > 0) MoneyValueObject(cents) else null
    }
}
