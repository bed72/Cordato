package com.bed.cordato.features.identity.infrastructure.repositories

import java.util.concurrent.ConcurrentHashMap

import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

import com.bed.cordato.features.identity.application.repositories.PersonRepository

/**
 * In-memory [PersonRepository] for this slice — keyed by e-mail so uniqueness is
 * cheap to answer. A real, persistent adapter replaces it later without touching
 * the application, since both honor the same port.
 */
class InMemoryPersonRepository : PersonRepository {
    private val byEmail = ConcurrentHashMap<String, PersonEntity>()

    override fun existsByEmail(email: EmailValueObject): Boolean = byEmail.containsKey(email.value)

    override fun save(person: PersonEntity) {
        byEmail[person.email.value] = person
    }
}
