package com.bed.cordato.features.identity.domain.value_objects

/**
 * A plaintext password that satisfies the public minimum policy ([MIN_LENGTH]).
 * Exists only long enough to be handed to a hasher — it is never stored. Construct
 * via [of], which returns null when the policy is not met. Not trimmed: whitespace
 * is a legitimate password character.
 */
@JvmInline
value class PasswordValueObject private constructor(val value: String) {
    companion object {
        const val MIN_LENGTH = 8

        fun of(raw: String): PasswordValueObject? =
            if (raw.length >= MIN_LENGTH) PasswordValueObject(raw) else null
    }
}
