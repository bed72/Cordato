package com.bed.cordato.core.domain.value_objects

import java.time.Instant

/**
 * The closed set of types a log attribute may carry — text, number, boolean or instant — so a
 * caller can never pass a whole entity/value object as an attribute by accident (a `Map<String,
 * Any?>` would allow exactly that). Forces the caller to extract the specific field worth logging.
 */
sealed interface LoggableValueObject {
    @JvmInline value class Text(val value: String) : LoggableValueObject
    @JvmInline value class Flag(val value: Boolean) : LoggableValueObject
    @JvmInline value class Moment(val value: Instant) : LoggableValueObject
    @JvmInline value class Number(val value: kotlin.Number) : LoggableValueObject
}
