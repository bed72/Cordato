package com.bed.cordato.features.identity.infrastructure.repositories

import org.jooq.DSLContext
import org.jooq.exception.DataAccessException

import com.bed.cordato.core.infrastructure.persistence.models.Tables.PERSON

import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

import com.bed.cordato.features.identity.infrastructure.repositories.mappers.toEntity
import com.bed.cordato.features.identity.infrastructure.repositories.mappers.toRecord

import com.bed.cordato.features.identity.application.driven.outcomes.UpdateEmailOutcome
import com.bed.cordato.features.identity.application.driven.repositories.PersonRepository

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

    // E-mail-only UPDATE, gated on the ACTIVE status in the WHERE so a person deleted between the guard and
    // this write matches zero rows (PERSON_INACTIVE) — no half-update. Uniqueness is authoritative at the
    // datastore: a colliding e-mail raises the unique-violation, caught and mapped to EMAIL_TAKEN, so a
    // concurrent race can never persist two equal e-mails and no datastore exception crosses into application.
    override fun updateEmail(id: String, email: EmailValueObject): UpdateEmailOutcome =
        try {
            val updated = dsl.update(PERSON)
                .set(PERSON.EMAIL, email.value)
                .where(PERSON.ID.eq(id))
                .and(PERSON.STATUS.eq(PersonStatusEnum.ACTIVE.name))
                .execute() > 0

            if (updated) UpdateEmailOutcome.UPDATED else UpdateEmailOutcome.PERSON_INACTIVE
        } catch (exception: DataAccessException) {
            if (exception.sqlState() == UNIQUE_VIOLATION) UpdateEmailOutcome.EMAIL_TAKEN else throw exception
        }

    // Hash-only UPDATE, gated on the ACTIVE status in the WHERE so a person deleted between the guard and this
    // write matches zero rows — no half-update. Zero rows affected ⇒ false ⇒ the use case's PersonNotFound,
    // the same neutral outcome findById reports for a non-active person. The password is not unique, so there
    // is no uniqueness conflict to catch — two states suffice.
    override fun updatePassword(id: String, hash: String): Boolean =
        dsl.update(PERSON)
            .set(PERSON.HASH, hash)
            .where(PERSON.ID.eq(id))
            .and(PERSON.STATUS.eq(PersonStatusEnum.ACTIVE.name))
            .execute() > 0

    // E-mail-neutralize-and-status UPDATE, gated on the ACTIVE status in the WHERE so a person already
    // deleted (or never existent) matches zero rows — no half-update. The neutralized address is unique by
    // construction (it carries the person's own id) and syntactically valid through EmailValueObject.of, so
    // there is no uniqueness conflict to catch here, unlike updateEmail.
    override fun deleteAccount(id: String): Boolean {
        val neutralizedEmail = checkNotNull(EmailValueObject.of("deleted+$id@deleted.invalid")) {
            "Neutralized e-mail for person $id failed EmailValueObject's own format rule"
        }

        return dsl.update(PERSON)
            .set(PERSON.EMAIL, neutralizedEmail.value)
            .set(PERSON.STATUS, PersonStatusEnum.DELETED.name)
            .where(PERSON.ID.eq(id))
            .and(PERSON.STATUS.eq(PersonStatusEnum.ACTIVE.name))
            .execute() > 0
    }

    private companion object {
        const val UNIQUE_VIOLATION = "23505"
    }
}
