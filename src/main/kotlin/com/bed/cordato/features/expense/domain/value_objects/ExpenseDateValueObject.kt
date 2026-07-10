package com.bed.cordato.features.expense.domain.value_objects

import java.time.LocalDate

/**
 * The calendar day a spend actually happened — the date in the real world, not the date it was typed in.
 * Wraps a [java.time.LocalDate] so the entity references a named domain type rather than a raw temporal.
 *
 * Construct via [of]. It validates only what is **intrinsic** to the date: a [LocalDate] is always a valid
 * calendar day (the HTTP parser already rejected a syntactically bad date with a `400` before the domain is
 * reached), so there is no intrinsic failure to report — hence [of] returns a non-null value, deliberately
 * diverging from the nullable `of()` convention of value objects that *do* carry a rejectable rule. The one
 * date rule that can fail — "never in the future" — depends on *today*, which only the `ClockPort` knows, so
 * it lives in the use case, not here (a pure value object never reaches for the clock). The default
 * "absent → today" is likewise the use case's decision.
 */
@JvmInline
value class ExpenseDateValueObject private constructor(val value: LocalDate) {
    companion object {
        fun of(raw: LocalDate): ExpenseDateValueObject = ExpenseDateValueObject(raw)
    }
}
