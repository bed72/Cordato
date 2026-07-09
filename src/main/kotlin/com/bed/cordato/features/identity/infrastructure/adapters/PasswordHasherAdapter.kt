package com.bed.cordato.features.identity.infrastructure.adapters

import at.favre.lib.crypto.bcrypt.BCrypt

import com.bed.cordato.features.identity.application.driven.ports.PasswordHasherPort
import com.bed.cordato.features.identity.domain.value_objects.PasswordValueObject

/**
 * [PasswordHasherPort] backed by bcrypt — the one place a crypto library is allowed.
 * The cost factor is the work parameter that makes automated guessing expensive.
 */
class PasswordHasherAdapter(private val cost: Int = DEFAULT_COST) : PasswordHasherPort {
    override fun create(password: PasswordValueObject): String =
        BCrypt.withDefaults().hashToString(cost, password.value.toCharArray())

    /**
     * Checks a raw attempt against [hash]. bcrypt reads the cost embedded in [hash], so verification
     * spends the same effort the hash was created with — this is what keeps login's timing constant
     * against the dummy hash. A malformed [hash] yields `false`, never an exception.
     */
    override fun verify(password: String, hash: String): Boolean =
        BCrypt.verifyer().verify(password.toCharArray(), hash.toCharArray()).verified

    companion object {
        const val DEFAULT_COST = 12
    }
}
