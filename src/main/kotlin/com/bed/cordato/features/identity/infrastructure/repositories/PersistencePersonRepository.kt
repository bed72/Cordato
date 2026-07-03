package com.bed.cordato.features.identity.infrastructure.repositories

import org.jooq.DSLContext
import org.jooq.exception.DataAccessException

import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

import com.bed.cordato.features.identity.application.repositories.PersonRepository

import com.bed.cordato.features.identity.infrastructure.repositories.mappers.toRecord
import com.bed.cordato.features.identity.infrastructure.repositories.models.Tables.PERSON

/**
 * Durable [PersonRepository] on PostgreSQL via jOOQ. Uniqueness is enforced by the
 * `person_email_key` UNIQUE constraint, so two concurrent signups can never both win —
 * the loser's INSERT raises a unique-violation, which is caught and mapped to the same
 * "already taken" outcome the use case handles. No datastore exception crosses into
 * application: the port's `Boolean` carries the result.
 */
class PersistencePersonRepository(private val dsl: DSLContext) : PersonRepository {

    override fun existsByEmail(email: EmailValueObject): Boolean =
        dsl.fetchExists(PERSON, PERSON.EMAIL.eq(email.value))

    override fun signUp(person: PersonEntity): Boolean =
        try {
            dsl.insertInto(PERSON)
                .set(person.toRecord())
                .execute()
            true
        } catch (exception: DataAccessException) {
            if (exception.sqlState() == UNIQUE_VIOLATION) false else throw exception
        }

    private companion object {
        const val UNIQUE_VIOLATION = "23505"
    }
}
