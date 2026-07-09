package com.bed.cordato.features.identity.application.driving.use_cases

import com.bed.cordato.core.application.driven.ports.ClockPort
import com.bed.cordato.core.application.driven.ports.TokenizerPort
import com.bed.cordato.core.application.driven.ports.IdGeneratorPort
import com.bed.cordato.core.application.driven.repositories.SessionRepository
import com.bed.cordato.core.domain.entities.SessionEntity

import com.bed.cordato.features.identity.domain.errors.SignInError
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

import com.bed.cordato.features.identity.application.driving.results.SignInResult
import com.bed.cordato.features.identity.application.driving.commands.SignInCommand
import com.bed.cordato.features.identity.application.driven.ports.PasswordHasherPort
import com.bed.cordato.features.identity.application.driven.repositories.PersonRepository

/**
 * Authenticates a person by e-mail and password and, on success, opens a session — the system's
 * first session producer.
 *
 * The order is the deliberate **inverse** of signup's "check existence before hashing" optimisation:
 * here `verify` is **always** paid, against the person's real hash when one exists and against a
 * fixed dummy hash of equivalent cost when it does not. Skipping the verify for an unknown e-mail
 * would turn response time into an account-discovery oracle — the very thing the single generic
 * [SignInError.InvalidCredentials] and the `401` hide from the body and status. Wrong password,
 * unknown e-mail, a malformed e-mail, and a non-active person therefore all collapse into the same
 * failure, indistinguishable by outcome or by timing.
 *
 * The public `invoke` signature is the driving (primary) side of this context.
 */
class SignInUseCase(
    private val clock: ClockPort,
    private val tokenizer: TokenizerPort,
    private val hasher: PasswordHasherPort,
    private val generator: IdGeneratorPort,
    private val personRepository: PersonRepository,
    private val sessionRepository: SessionRepository,
) {
    operator fun invoke(command: SignInCommand): SignInResult {
        val person = EmailValueObject.of(command.email)?.let(personRepository::findByEmail)

        // Always one verify, real or dummy — the cost must not reveal whether the e-mail exists.
        val authenticated = hasher.verify(command.password, person?.hash ?: DUMMY_HASH)
        if (person == null || !authenticated) {
            return SignInResult.Failure(SignInError.InvalidCredentials)
        }

        val now = clock()
        val token = tokenizer.generate()
        val session = SessionEntity(
            id = generator(),
            createdAt = now,
            personId = person.id,
            hashToken = tokenizer.hash(token),
            expiresAt = now.plus(SessionEntity.TTL),
        )
        // A false open means a token-hash collision (unreachable for a SecureRandom token); it is an
        // infrastructure anomaly, not a credentials refusal, so surface it as a 500 rather than lie 200.
        check(sessionRepository.open(session)) { "Failed to open a session for an authenticated person" }

        return SignInResult.Success(session, token)
    }

    private companion object {
        /**
         * A well-formed bcrypt hash the verify runs against when no real person is found, so an
         * unknown e-mail pays the same hashing cost as a wrong password. It MUST share the cost factor
         * of [com.bed.cordato.features.identity.infrastructure.adapters.PasswordHasherAdapter] (12) —
         * a cheaper dummy would reopen the timing oracle. No password ever matches it (that is fine;
         * only the cost matters).
         */
        const val DUMMY_HASH = "\$2a\$12\$BDGLFH8gboVw1dbjlZvOeeLcWmBcMa3bkpbeW5O3GGDPm5a5j/i.."
    }
}
