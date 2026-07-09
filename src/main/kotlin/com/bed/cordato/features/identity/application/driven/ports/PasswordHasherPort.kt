package com.bed.cordato.features.identity.application.driven.ports

import com.bed.cordato.features.identity.domain.value_objects.PasswordValueObject

/**
 * Driven port that turns a validated plaintext password into an irreversible hash string, and
 * checks a raw plaintext attempt against an existing hash. The algorithm (bcrypt/argon2) lives in
 * infrastructure so the domain and application stay free of any crypto library.
 *
 * [create] takes a [PasswordValueObject] because a *new* password must satisfy the signup policy
 * first. [verify] takes a raw `String` on purpose: login re-checks nothing about policy — a password
 * that was valid when set must still authenticate even if the policy later tightened — it only asks
 * whether the attempt matches the stored [hash].
 */
interface PasswordHasherPort {
    fun create(password: PasswordValueObject): String

    fun verify(password: String, hash: String): Boolean
}
