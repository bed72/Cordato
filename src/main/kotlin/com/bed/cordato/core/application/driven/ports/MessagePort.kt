package com.bed.cordato.core.application.driven.ports

/**
 * Core's own contract for turning a message key into displayable text — the single seam every HTTP call
 * site (core's error handlers and each feature's error mapper) depends on, instead of a framework type.
 * Keeping the abstraction ours means the edge code names no Micronaut symbol and stays mockable without
 * standing up the framework; the sole implementation ([com.bed.cordato.core.infrastructure.adapters.MessageAdapter]) is the one place the
 * request-scoped, `Accept-Language`-aware source is touched.
 *
 * Resolution is fallback-to-key: a missing key yields the key itself — a visible, non-leaking signal of a
 * bundle typo rather than a thrown exception on a response path (an error handler must never fail to build
 * a body).
 */
interface MessagePort {
    operator fun invoke(key: String, variables: Map<String, Any> = emptyMap()): String
}