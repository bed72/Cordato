package com.bed.cordato.core.infrastructure.repositories.mappers

import java.time.ZoneOffset

import com.bed.cordato.core.infrastructure.http.responses.entities.SessionEntity

import com.bed.cordato.core.infrastructure.persistence.models.tables.records.SessionRecord

/**
 * Translates between the domain [SessionEntity] and the jOOQ-generated [SessionRecord] at the
 * infrastructure boundary, as `internal` extension functions so call sites read fluently
 * (`session.toRecord()` / `record.toEntity()`). The `timestamp with time zone` columns surface as
 * `OffsetDateTime`, so the instants are pinned to UTC on the way out and unwrapped back to
 * [java.time.Instant] on the way in. The generated record type never escapes infrastructure — only
 * entities cross back into application.
 */
internal fun SessionEntity.toRecord(): SessionRecord = SessionRecord().also { record ->
    record.id = id
    record.personId = personId
    record.hashToken = hashToken
    record.expiresAt = expiresAt.atOffset(ZoneOffset.UTC)
    record.createdAt = createdAt.atOffset(ZoneOffset.UTC)
}

internal fun SessionRecord.toEntity(): SessionEntity = SessionEntity(
    id = id,
    personId = personId,
    hashToken = hashToken,
    expiresAt = expiresAt.toInstant(),
    createdAt = createdAt.toInstant(),
)
