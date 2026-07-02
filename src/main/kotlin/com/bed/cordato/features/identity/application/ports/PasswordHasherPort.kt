package com.bed.cordato.features.identity.application.ports

import com.bed.cordato.features.identity.domain.value_objects.PasswordValueObject

/**
 * Driven port that turns a validated plaintext password into an irreversible hash
 * string. The algorithm (bcrypt/argon2) lives in infrastructure so the domain and
 * application stay free of any crypto library.
 */
fun interface PasswordHasherPort {
    fun hash(password: PasswordValueObject): String
}
