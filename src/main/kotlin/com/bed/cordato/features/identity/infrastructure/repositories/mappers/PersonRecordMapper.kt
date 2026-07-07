package com.bed.cordato.features.identity.infrastructure.repositories.mappers

import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

import com.bed.cordato.core.infrastructure.persistence.models.tables.records.PersonRecord

/**
 * Translates between the domain [PersonEntity] and the jOOQ-generated [PersonRecord] at the
 * infrastructure boundary, as `internal` extension functions so call sites read fluently
 * (`person.toRecord()` / `record.toEntity()`). Value objects are unwrapped to their `text`
 * columns on the way out and re-validated on the way in; [PersonStatusEnum] maps to/from its
 * `name`. The generated record type never escapes infrastructure — only entities cross back
 * into application.
 */
internal fun PersonEntity.toRecord(): PersonRecord = PersonRecord().also { record ->
    record.id = id
    record.hash = hash
    record.name = name.value
    record.email = email.value
    record.status = status.name
}

/**
 * Rebuilds a [PersonEntity] from a stored row. The e-mail/name are trusted (they were validated
 * before they were ever written), so a value that no longer parses is a data-integrity fault,
 * surfaced loudly rather than silently dropped.
 */
internal fun PersonRecord.toEntity(): PersonEntity = PersonEntity(
    id = id,
    hash = hash,
    status = PersonStatusEnum.valueOf(status),
    name = checkNotNull(NameValueObject.of(name)) { "Stored person name is invalid: $name" },
    email = checkNotNull(EmailValueObject.of(email)) { "Stored person e-mail is invalid: $email" },
)
