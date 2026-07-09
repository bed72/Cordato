package com.bed.cordato.core.infrastructure.adapters

import java.util.Base64
import java.security.SecureRandom
import java.security.MessageDigest

import com.bed.cordato.core.application.driven.ports.TokenizerPort

/**
 * [TokenizerPort] backed by the JDK alone — no new dependency. [generate] draws
 * [TOKEN_BYTES] bytes from a [SecureRandom] and encodes them as base64url without padding, an
 * opaque token with enough entropy to be impractical to guess. [hash] is the SHA-256 of the
 * token's UTF-8 bytes, hex-encoded — a fixed-length digest that is what gets persisted, so a
 * storage leak never exposes a usable token. A hash is a fresh [MessageDigest] each call
 * (`MessageDigest` instances are not thread-safe).
 */
class TokenizerAdapter(private val random: SecureRandom = SecureRandom()) : TokenizerPort {

    override fun generate(): String {
        val bytes = ByteArray(TOKEN_BYTES)
        random.nextBytes(bytes)

        return ENCODER.encodeToString(bytes)
    }

    override fun hash(token: String): String =
        MessageDigest.getInstance(DIGEST_ALGORITHM)
            .digest(token.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }

    private companion object {
        const val TOKEN_BYTES = 32
        const val DIGEST_ALGORITHM = "SHA-256"

        val ENCODER: Base64.Encoder = Base64.getUrlEncoder().withoutPadding()
    }
}
