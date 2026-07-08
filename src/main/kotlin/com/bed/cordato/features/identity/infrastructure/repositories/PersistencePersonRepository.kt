package com.bed.cordato.features.identity.infrastructure.repositories

import org.jooq.DSLContext
import org.jooq.exception.DataAccessException

import com.bed.cordato.core.infrastructure.persistence.models.Tables.PERSON

import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

import com.bed.cordato.features.identity.application.repositories.PersonRepository

import com.bed.cordato.features.identity.infrastructure.repositories.mappers.toEntity
import com.bed.cordato.features.identity.infrastructure.repositories.mappers.toRecord

/**
 * Durable [PersonRepository] on PostgreSQL via jOOQ. Uniqueness is enforced by the
 * `person_email_key` UNIQUE constraint, so two concurrent signups can never both win —
 * the loser's INSERT raises a unique-violation, which is caught and mapped to the same
 * "already taken" outcome the use case handles. No datastore exception crosses into
 * application: the port's `Boolean` carries the result.
 */
class PersistencePersonRepository(private val dsl: DSLContext) : PersonRepository {

    override fun signUp(person: PersonEntity): Boolean =
        try {
            dsl.insertInto(PERSON)
                .set(person.toRecord())
                .execute()

            true
        } catch (exception: DataAccessException) {
            if (exception.sqlState() == UNIQUE_VIOLATION) false else throw exception
        }

    override fun existsByEmail(email: EmailValueObject): Boolean =
        dsl.fetchExists(PERSON, PERSON.EMAIL.eq(email.value))

    override fun findByEmail(email: EmailValueObject): PersonEntity? =
        dsl.selectFrom(PERSON)
            .where(PERSON.EMAIL.eq(email.value))
            .and(PERSON.STATUS.eq(PersonStatusEnum.ACTIVE.name))
            .fetchOne()
            ?.toEntity()

    override fun findById(id: String): PersonEntity? =
        dsl.selectFrom(PERSON)
            .where(PERSON.ID.eq(id))
            .and(PERSON.STATUS.eq(PersonStatusEnum.ACTIVE.name))
            .fetchOne()
            ?.toEntity()

    // Name-only UPDATE, gated on the ACTIVE status in the WHERE so a person deleted between the guard and
    // this write matches zero rows — no half-update. Zero rows affected ⇒ false ⇒ the use case's
    // PersonNotFound, the same neutral outcome findById reports for a non-active person.
    override fun updateName(id: String, name: NameValueObject): Boolean =
        dsl.update(PERSON)
            .set(PERSON.NAME, name.value)
            .where(PERSON.ID.eq(id))
            .and(PERSON.STATUS.eq(PersonStatusEnum.ACTIVE.name))
            .execute() > 0

    private companion object {
        const val UNIQUE_VIOLATION = "23505"
    }
}
