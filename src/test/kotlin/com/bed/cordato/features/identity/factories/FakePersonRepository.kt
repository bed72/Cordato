package com.bed.cordato.features.identity.factories

import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

import com.bed.cordato.features.identity.application.driven.repositories.PersonRepository
import com.bed.cordato.features.identity.application.driven.outcomes.UpdateEmailOutcome

class FakePersonRepository : PersonRepository {
    private val byEmail = mutableMapOf<String, PersonEntity>()

    override fun existsByEmail(email: EmailValueObject): Boolean = byEmail.containsKey(email.value)

    override fun signUp(person: PersonEntity): Boolean =
        byEmail.putIfAbsent(person.email.value, person) == null

    override fun findByEmail(email: EmailValueObject): PersonEntity? =
        byEmail[email.value]?.takeIf { it.status == PersonStatusEnum.ACTIVE }

    override fun findById(id: String): PersonEntity? =
        byEmail.values.firstOrNull { it.id == id }?.takeIf { it.status == PersonStatusEnum.ACTIVE }

    // Mirrors the production adapter: only the active person's name changes; a non-active person matches
    // nothing (false), and no other field is ever touched.
    override fun updateName(id: String, name: NameValueObject): Boolean {
        val person = findById(id) ?: return false
        byEmail[person.email.value] = person.copy(name = name)
        return true
    }

    // Mirrors the production adapter's three-state outcome: a non-active person matches nothing
    // (PERSON_INACTIVE); a new e-mail already held by another person is the uniqueness conflict
    // (EMAIL_TAKEN); otherwise only the active person's e-mail changes (UPDATED), re-keying the store and
    // leaving every other field untouched.
    override fun updateEmail(id: String, email: EmailValueObject): UpdateEmailOutcome {
        val person = findById(id) ?: return UpdateEmailOutcome.PERSON_INACTIVE
        val owner = byEmail[email.value]
        if (owner != null && owner.id != person.id) return UpdateEmailOutcome.EMAIL_TAKEN
        byEmail.remove(person.email.value)
        byEmail[email.value] = person.copy(email = email)
        return UpdateEmailOutcome.UPDATED
    }
}
