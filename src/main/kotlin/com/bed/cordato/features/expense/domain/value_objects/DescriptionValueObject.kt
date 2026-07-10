package com.bed.cordato.features.expense.domain.value_objects

/**
 * An optional free-text description of a spend: trimmed, no longer than [MAX_LENGTH].
 *
 * Construct via [of], which trims and returns null only when the trimmed text exceeds [MAX_LENGTH]. It does
 * **not** treat an empty result as an error: "blank → absent" is the use case's decision, made *before* it
 * calls [of] (a null/blank raw becomes no description at all), so a present description reaching [of] is
 * non-blank and only its length can reject it. This keeps "absent (fine)" and "too long (error)" from
 * collapsing into the same null.
 */
@JvmInline
value class DescriptionValueObject private constructor(val value: String) {
    companion object {
        const val MAX_LENGTH = 255

        fun of(raw: String): DescriptionValueObject? {
            val trimmed = raw.trim()
            return if (trimmed.length <= MAX_LENGTH) DescriptionValueObject(trimmed) else null
        }
    }
}
