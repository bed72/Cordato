package com.bed.cordato.features.identity.infrastructure.http.errors

import io.micronaut.serde.annotation.Serdeable

/**
 * The single, shared error body used for every failure — one shape for all rejections so the
 * body structure itself is never a tell. [code] is a stable machine-readable token; [message]
 * is human-readable and, for the e-mail-conflict case, deliberately generic (see
 * [com.bed.cordato.features.identity.infrastructure.http.mappers.toHttpResponse]) so the endpoint can't be used to probe which e-mails are registered.
 */
@Serdeable
data class ErrorResponse(
    val code: String,
    val message: String,
)
