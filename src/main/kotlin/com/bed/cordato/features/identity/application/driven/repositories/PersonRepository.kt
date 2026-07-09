package com.bed.cordato.features.identity.application.driven.repositories

import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

import com.bed.cordato.features.identity.application.driven.outcomes.UpdateEmailOutcome

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

    /**
     * Resolves the **active** person for [id], or `null`. Mirrors [findByEmail]'s neutrality: a
     * non-existent id and an id whose person is not active (deleted/inactive) collapse to the same
     * absent result, never a non-active person — so an orphaned session cannot tell the cases apart.
     */
    fun findById(id: String): PersonEntity?

    fun existsByEmail(email: EmailValueObject): Boolean

    /**
     * Resolves the **active** person for [email], or `null`. A non-existent e-mail and an e-mail
     * whose person is not active (deleted/inactive) collapse to the same absent result, never a
     * non-active person — keeping login's account-discovery non-leak invariant at the query layer.
     */
    fun findByEmail(email: EmailValueObject): PersonEntity?

    /**
     * Updates **only** the name of the **active** person for [id], leaving e-mail, password hash, status and
     * identifier untouched. Deliberately narrow (name-only, not a generic `save(person)`) so the persistence
     * boundary cannot rewrite any other field.
     *
     * @return `true` when the active person's name was updated; `false` when no active person matches [id]
     *   (never existed, or a race with account deletion left it non-active) — zero rows affected collapses to
     *   the same absent result [findById] reports, so the use case maps it to `PersonNotFound`.
     */
    fun updateName(id: String, name: NameValueObject): Boolean

    /**
     * Updates **only** the e-mail of the **active** person for [id], leaving name, password hash, status and
     * identifier untouched. Deliberately narrow (e-mail-only, not a generic `save(person)`) so the
     * persistence boundary cannot rewrite any other field, and **authoritative** on global uniqueness — the
     * datastore's unique constraint decides the conflict, closing the concurrent race a mere pre-check
     * cannot.
     *
     * @return [UpdateEmailOutcome.UPDATED] when the active person's e-mail was changed;
     *   [UpdateEmailOutcome.EMAIL_TAKEN] when [email] already belongs to another person (the losing side of a
     *   uniqueness conflict, never a leaked datastore exception); [UpdateEmailOutcome.PERSON_INACTIVE] when no
     *   active person matches [id] (never existed, or a race with account deletion left it non-active — zero
     *   rows affected), the same absent result [findById] reports.
     */
    fun updateEmail(id: String, email: EmailValueObject): UpdateEmailOutcome

    /**
     * Updates **only** the password hash of the **active** person for [id], leaving name, e-mail, status and
     * identifier untouched. Deliberately narrow (hash-only, not a generic `save(person)`) so the persistence
     * boundary cannot rewrite any other field. Takes the already-hashed [hash] — the plaintext never reaches
     * persistence.
     *
     * @return `true` when the active person's hash was updated; `false` when no active person matches [id]
     *   (never existed, or a race with account deletion left it non-active) — zero rows affected collapses to
     *   the same absent result [findById] reports, so the use case maps it to `PersonNotFound`. The password
     *   is not unique, so two states suffice (unlike [updateEmail]'s three-state outcome).
     */
    fun updatePassword(id: String, hash: String): Boolean

}