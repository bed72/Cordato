package com.bed.cordato.features.identity.domain.value_objects

/**
 * A syntactically valid, normalized (trimmed + lowercased) e-mail address.
 * Construct via [of], which returns null for an invalid format — validity is the
 * type's own rule, never the caller's.
 */
@JvmInline
value class EmailValueObject private constructor(val value: String) {
    companion object {
        private val PATTERN = Regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")

        fun of(raw: String): EmailValueObject? {
            val normalized = raw.trim().lowercase()
            return if (PATTERN.matches(normalized)) EmailValueObject(normalized) else null
        }
    }
}
