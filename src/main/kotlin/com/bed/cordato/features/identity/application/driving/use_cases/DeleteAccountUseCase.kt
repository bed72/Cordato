package com.bed.cordato.features.identity.application.driving.use_cases

import com.bed.cordato.core.application.driven.repositories.SessionRepository

import com.bed.cordato.features.identity.domain.errors.DeleteAccountError

import com.bed.cordato.features.identity.application.driven.ports.PasswordHasherPort
import com.bed.cordato.features.identity.application.driving.results.DeleteAccountResult
import com.bed.cordato.features.identity.application.driven.repositories.PersonRepository
import com.bed.cordato.features.identity.application.driving.commands.DeleteAccountCommand
import com.bed.cordato.features.identity.application.driven.ports.PersonOwnedFinancialsPort

/**
 * Deletes the authenticated person's own account from the session identity the edge guard already settled —
 * the single genuinely destructive and irreversible operation in the whole system, so it is a step-up
 * operation confirming the current password, and it ends **all** of the person's live sessions once
 * everything else has succeeded.
 *
 * The order is deliberate (see design.md's "cascade first, person write is the point of no return, sessions
 * last"):
 * 1. Resolve the **active** person for the `personId` (never re-reading the token); an absent person — never
 *    existed, or a race with a concurrent deletion left it non-active — is [DeleteAccountError.PersonNotFound],
 *    which the edge maps to the same neutral `401` a missing session yields.
 * 2. Confirm the current password against the stored hash **before** any effect; a mismatch is
 *    [DeleteAccountError.InvalidCredentials], mapped to that same neutral `401`.
 * 3. Trigger the cascade — hard-delete every budget and expense the person owns — through
 *    [PersonOwnedFinancialsPort]. Placed *before* the person write: if this throws (an infrastructure
 *    exception, never a domain value), the person is still `ACTIVE`, the caller still holds a valid session
 *    and can safely retry.
 * 4. Neutralize the e-mail and transition status to `DELETED` via the narrow [PersonRepository.deleteAccount]
 *    — the **point of no return**. A lost race there (the person went non-active between the read and the
 *    write) collapses to [DeleteAccountError.PersonNotFound].
 * 5. Only after the person row is gone, revoke **every** live session of the person
 *    ([SessionRepository.revokeAllForPerson], no exclusion — unlike password rotation, there is no session
 *    left to spare) — the final side effect, never run on a failed write.
 *
 * No exception is thrown on any domain path. The public `invoke` signature is the driving (primary) side of
 * this context.
 */
class DeleteAccountUseCase(
    private val hasher: PasswordHasherPort,
    private val personRepository: PersonRepository,
    private val sessionRepository: SessionRepository,
    private val personOwnedFinancialsPort: PersonOwnedFinancialsPort,
) {
    operator fun invoke(command: DeleteAccountCommand): DeleteAccountResult {
        val person = personRepository.findById(command.personId)
            ?: return DeleteAccountResult.Failure(DeleteAccountError.PersonNotFound)

        if (!hasher.verify(command.password, person.hash)) {
            return DeleteAccountResult.Failure(DeleteAccountError.InvalidCredentials)
        }

        personOwnedFinancialsPort(person.id)

        if (!personRepository.deleteAccount(person.id)) {
            return DeleteAccountResult.Failure(DeleteAccountError.PersonNotFound)
        }

        sessionRepository.revokeAllForPerson(person.id)

        return DeleteAccountResult.Success
    }
}
