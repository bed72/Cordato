package com.bed.cordato.features.identity.factories

import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

import com.bed.cordato.features.identity.application.repositories.PersonRepository

class FakePersonRepository : PersonRepository {
    private val byEmail = mutableMapOf<String, PersonEntity>()

    override fun existsByEmail(email: EmailValueObject): Boolean = byEmail.containsKey(email.value)

    override fun signUp(person: PersonEntity): Boolean =
        byEmail.putIfAbsent(person.email.value, person) == null

    override fun findByEmail(email: EmailValueObject): PersonEntity? =
        byEmail[email.value]?.takeIf { it.status == PersonStatusEnum.ACTIVE }

    override fun findById(id: String): PersonEntity? =
        byEmail.values.firstOrNull { it.id == id }?.takeIf { it.status == PersonStatusEnum.ACTIVE }
}
