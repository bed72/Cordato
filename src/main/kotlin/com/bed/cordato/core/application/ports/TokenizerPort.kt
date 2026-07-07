package com.bed.cordato.core.application.ports

/**
 * Driven port for opaque session tokens. [generate] mints a fresh, cryptographically-secure
 * token in the clear (returned to the client once); [hash] derives the SHA-256 that is the only
 * form ever persisted. Resolving a session by token hashes the presented token and compares —
 * the plaintext is never stored and never recovered. The crypto primitives (`SecureRandom`,
 * `MessageDigest`) live in core/infrastructure so domain and application stay free of them.
 */
interface TokenizerPort {
    fun generate(): String

    fun hash(token: String): String
}
