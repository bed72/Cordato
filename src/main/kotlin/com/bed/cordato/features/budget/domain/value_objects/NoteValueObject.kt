package com.bed.cordato.features.budget.domain.value_objects

/**
 * An optional free-text note on a budget: trimmed, no longer than [MAX_LENGTH]. Same shape as expense's
 * `DescriptionValueObject` (255, the same value by consistency), but its own type — `budget` never depends
 * on `expense`.
 *
 * Construct via [of], which trims and returns null only when the trimmed text exceeds [MAX_LENGTH]. It does
 * **not** treat an empty result as an error: "blank → absent" is the use case's decision, made *before* it
 * calls [of] (a null/blank raw becomes no note at all), so a present note reaching [of] is non-blank and
 * only its length can reject it.
 */
@JvmInline
value class NoteValueObject private constructor(val value: String) {
    companion object {
        const val MAX_LENGTH = 255

        fun of(raw: String): NoteValueObject? {
            val trimmed = raw.trim()
            return if (trimmed.length <= MAX_LENGTH) NoteValueObject(trimmed) else null
        }
    }
}
