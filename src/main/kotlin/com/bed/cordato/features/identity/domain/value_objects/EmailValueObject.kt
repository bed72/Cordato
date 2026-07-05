package com.bed.cordato.features.identity.domain.value_objects

/**
 * A syntactically valid, normalized (trimmed + lowercased) e-mail address.
 * Construct via [of], which returns null for an invalid format — validity is the
 * type's own rule, never the caller's.
 */
@JvmInline
value class EmailValueObject private constructor(val value: String) {
    companion object {
        /**
         * The e-mail format, as a compile-time constant so the HTTP edge can reuse the *same*
         * definition (`@Pattern(regexp = EmailValueObject.PATTERN)`) instead of a second regex —
         * one source of truth for the rule. Note the edge validates the raw value, while [of]
         * validates the trimmed/lowercased one, so the edge is a strict superset of this check.
         */
        const val PATTERN = "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"

        private val REGEX = Regex(PATTERN)

        fun of(raw: String): EmailValueObject? {
            val normalized = raw.trim().lowercase()
            return if (REGEX.matches(normalized)) EmailValueObject(normalized) else null
        }
    }
}
