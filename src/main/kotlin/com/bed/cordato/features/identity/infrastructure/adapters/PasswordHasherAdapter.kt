package com.bed.cordato.features.identity.infrastructure.adapters

import at.favre.lib.crypto.bcrypt.BCrypt

import com.bed.cordato.features.identity.application.ports.PasswordHasherPort
import com.bed.cordato.features.identity.domain.value_objects.PasswordValueObject

/**
 * [PasswordHasherPort] backed by bcrypt — the one place a crypto library is allowed.
 * The cost factor is the work parameter that makes automated guessing expensive.
 */
class PasswordHasherAdapter(private val cost: Int = DEFAULT_COST) : PasswordHasherPort {
    override fun invoke(password: PasswordValueObject): String =
        BCrypt.withDefaults().hashToString(cost, password.value.toCharArray())

    companion object {
        const val DEFAULT_COST = 12
    }
}
