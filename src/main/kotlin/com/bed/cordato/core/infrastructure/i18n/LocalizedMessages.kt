package com.bed.cordato.core.infrastructure.i18n

import io.micronaut.context.LocalizedMessageSource

/**
 * The single resolution policy every HTTP call site shares when turning a message key into displayable
 * text — core's error handlers and each feature's error mapper alike. Resolves [key] against the
 * request-localized bundle (via the `Accept-Language`-aware [LocalizedMessageSource]) and, when the key
 * is somehow missing, falls back to the key itself: a visible, non-leaking signal of a bundle typo
 * rather than a thrown exception on a response path (an error handler must never fail to build a body).
 *
 * Centralizing it here keeps the fallback behaviour from drifting between the five migrated sites and
 * gives the cross-cutting HTTP layer one place that owns "key → text", mirroring how `core` already owns
 * the shared error-response shape.
 */
internal fun LocalizedMessageSource.resolve(key: String, variables: Map<String, Any> = emptyMap()): String =
    getMessageOrDefault(key, key, variables)
