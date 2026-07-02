package com.bed.cordato.features.identity.domain.value_objects

/**
 * A valid person name: non-blank once trimmed, no longer than [MAX_LENGTH].
 * Construct via [of], which returns null when the name is invalid.
 */
@JvmInline
value class NameValueObject private constructor(val value: String) {
    companion object {
        const val MAX_LENGTH = 32

        fun of(raw: String): NameValueObject? {
            val trimmed = raw.trim()
            return if (trimmed.isNotEmpty() && trimmed.length <= MAX_LENGTH) NameValueObject(trimmed) else null
        }
    }
}
