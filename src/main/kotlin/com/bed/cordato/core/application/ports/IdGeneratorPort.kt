package com.bed.cordato.core.application.ports

/**
 * Determinism port: a fresh, unique identifier as an opaque string, stored directly
 * on entities. Implemented in core/infrastructure.
 */
fun interface IdGeneratorPort {
    operator fun invoke(): String
}
