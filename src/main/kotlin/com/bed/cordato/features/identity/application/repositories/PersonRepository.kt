package com.bed.cordato.features.identity.application.repositories

import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

/**
 * Driven port for person persistence. [existsByEmail] backs the cheap uniqueness pre-check
 * the use case runs before the expensive password hashing; it cannot close the concurrent
 * signup race, so [signUp] is authoritative. Implemented in infrastructure.
 */
interface PersonRepository {
    /**
     * Persists [person], enforcing e-mail uniqueness at the datastore.
     *
     * @return `true` when the row was inserted; `false` when a person with this e-mail
     *   already exists (the losing side of a uniqueness conflict). A `false` result never
     *   leaks a datastore exception — it is the same conflict the pre-check reports.
     */
    fun signUp(person: PersonEntity): Boolean

    fun existsByEmail(email: EmailValueObject): Boolean

    /**
     * Resolves the **active** person for [email], or `null`. A non-existent e-mail and an e-mail
     * whose person is not active (deleted/inactive) collapse to the same absent result, never a
     * non-active person — keeping login's account-discovery non-leak invariant at the query layer.
     */
    fun findByEmail(email: EmailValueObject): PersonEntity?
}