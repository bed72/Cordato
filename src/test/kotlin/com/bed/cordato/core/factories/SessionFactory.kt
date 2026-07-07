package com.bed.cordato.core.factories

import java.time.Instant

import com.bed.cordato.core.domain.entities.SessionEntity

fun session(
    id: String = "session-1",
    personId: String = "person-1",
    hashToken: String = "hashed-token",
    createdAt: Instant = Instant.parse("2026-07-07T12:00:00Z"),
    expiresAt: Instant = createdAt.plus(SessionEntity.TTL),
): SessionEntity = SessionEntity(
    id = id,
    personId = personId,
    hashToken = hashToken,
    expiresAt = expiresAt,
    createdAt = createdAt,
)
