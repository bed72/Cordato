package com.bed.cordato.features.identity.application.repositories

import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

/**
 * Driven port for person persistence. [existsByEmail] backs the uniqueness check the
 * use case runs before the expensive password hashing. Implemented in infrastructure.
 */
interface PersonRepository {
    fun save(person: PersonEntity)

    fun existsByEmail(email: EmailValueObject): Boolean
}