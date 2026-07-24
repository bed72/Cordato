package com.bed.cordato.features.identity.factories

import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

import com.bed.cordato.features.identity.application.driven.outcomes.UpdateEmailOutcome
import com.bed.cordato.features.identity.application.driven.repositories.PersonRepository

class FakePersonRepository : PersonRepository {
    private val byEmail = mutableMapOf<String, PersonEntity>()

    override fun existsByEmail(email: EmailValueObject): Boolean = byEmail.containsKey(email.value)

    override fun signUp(person: PersonEntity): Boolean =
        byEmail.putIfAbsent(person.email.value, person) == null

    override fun findByEmail(email: EmailValueObject): PersonEntity? =
        byEmail[email.value]?.takeIf { it.status == PersonStatusEnum.ACTIVE }

    override fun findById(id: String): PersonEntity? =
        byEmail.values.firstOrNull { it.id == id }?.takeIf { it.status == PersonStatusEnum.ACTIVE }

    override fun updateName(id: String, name: NameValueObject): Boolean {
        val person = findById(id) ?: return false
        byEmail[person.email.value] = person.copy(name = name)
        return true
    }

    override fun updateEmail(id: String, email: EmailValueObject): UpdateEmailOutcome {
        val person = findById(id) ?: return UpdateEmailOutcome.PERSON_INACTIVE
        val owner = byEmail[email.value]
        if (owner != null && owner.id != person.id) return UpdateEmailOutcome.EMAIL_TAKEN
        byEmail.remove(person.email.value)
        byEmail[email.value] = person.copy(email = email)
        return UpdateEmailOutcome.UPDATED
    }

    override fun updatePassword(id: String, hash: String): Boolean {
        val person = findById(id) ?: return false
        byEmail[person.email.value] = person.copy(hash = hash)
        return true
    }

    override fun deleteAccount(id: String): Boolean {
        val person = findById(id) ?: return false
        val neutralizedEmail = checkNotNull(EmailValueObject.of("deleted+$id@deleted.invalid"))

        byEmail.remove(person.email.value)
        byEmail[neutralizedEmail.value] = person.copy(email = neutralizedEmail, status = PersonStatusEnum.DELETED)
        return true
    }
}
