package com.bed.cordato.features.identity.application.driving.use_cases

import com.bed.cordato.core.application.driven.repositories.SessionRepository

import com.bed.cordato.features.identity.domain.errors.UpdatePasswordError
import com.bed.cordato.features.identity.domain.value_objects.PasswordValueObject

import com.bed.cordato.features.identity.application.driven.ports.PasswordHasherPort
import com.bed.cordato.features.identity.application.driving.results.UpdatePasswordResult
import com.bed.cordato.features.identity.application.driven.repositories.PersonRepository
import com.bed.cordato.features.identity.application.driving.commands.UpdatePasswordCommand

/**
 * Changes the authenticated person's own password from the session identity the edge guard already settled —
 * the most sensitive self-service write after account deletion, so it is a step-up operation confirming the
 * current password, and it ends the person's **other** live sessions once the new password is in place.
 *
 * The order is deliberate:
 * 1. Build the [PasswordValueObject] from the raw new password — the value object is the single authority on
 *    the policy, so a rejected password is [UpdatePasswordError.WeakPassword] (a public rule), not a thrown
 *    error, and nothing is touched.
 * 2. Resolve the **active** person for the `personId` (never re-reading the token); an absent person — never
 *    existed, or a race with account deletion left it non-active — is [UpdatePasswordError.PersonNotFound],
 *    which the edge maps to the same neutral `401` a missing session yields.
 * 3. Confirm the current password against the stored hash **before** any write; a mismatch is
 *    [UpdatePasswordError.InvalidCredentials], mapped to that same neutral `401`.
 * 4. If the new password matches the stored hash it equals the current one — [UpdatePasswordError.SamePassword]
 *    (a null rotation refused, not a silent no-op), decided by `verify` after the current-password check.
 * 5. Hash the new password and persist it via the narrow [PersonRepository.updatePassword]; a lost race there
 *    (the person went non-active between the read and the write) collapses to [UpdatePasswordError.PersonNotFound].
 * 6. Only after the password is persisted, revoke the person's other live sessions, sparing the current one
 *    ([SessionRepository.revokeAllForPersonExcept]) — the **final** side effect, never run on a failed write.
 * 7. Return the public view (unchanged by a password rotation, but returned for uniformity with name/e-mail).
 *
 * No exception is thrown on any domain path. The public `invoke` signature is the driving (primary) side of
 * this context.
 */
class UpdatePasswordUseCase(
    private val hasher: PasswordHasherPort,
    private val personRepository: PersonRepository,
    private val sessionRepository: SessionRepository,
) {
    operator fun invoke(command: UpdatePasswordCommand): UpdatePasswordResult {
        val password = PasswordValueObject.of(command.newPassword)
            ?: return UpdatePasswordResult.Failure(UpdatePasswordError.WeakPassword)

        val person = personRepository.findById(command.personId)
            ?: return UpdatePasswordResult.Failure(UpdatePasswordError.PersonNotFound)

        if (!hasher.verify(command.currentPassword, person.hash)) {
            return UpdatePasswordResult.Failure(UpdatePasswordError.InvalidCredentials)
        }

        if (hasher.verify(command.newPassword, person.hash)) {
            return UpdatePasswordResult.Failure(UpdatePasswordError.SamePassword)
        }

        if (!personRepository.updatePassword(person.id, hasher.create(password))) {
            return UpdatePasswordResult.Failure(UpdatePasswordError.PersonNotFound)
        }

        sessionRepository.revokeAllForPersonExcept(command.personId, command.sessionId)

        return UpdatePasswordResult.Success(person)
    }
}
