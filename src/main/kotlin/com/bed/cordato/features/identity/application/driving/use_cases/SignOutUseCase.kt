package com.bed.cordato.features.identity.application.driving.use_cases

import com.bed.cordato.core.application.driven.repositories.SessionRepository

import com.bed.cordato.features.identity.application.driving.results.SignOutResult
import com.bed.cordato.features.identity.application.driving.commands.SignOutCommand

/**
 * Ends the authenticated person's own current session (logout) from the session identity the edge guard
 * already settled — it never re-reads the token or looks up the person, only revokes the [SessionRepository]
 * entry for the `sessionId` the guard resolved.
 *
 * There is nothing to branch on: the guard could not have reached this use case without a currently-live
 * session, and revoking one that turns out to already be gone (a benign race, e.g. two concurrent logout
 * calls) is still success from the caller's perspective — [SessionRepository.revoke]'s `Boolean` result is
 * intentionally not inspected here.
 *
 * The public `invoke` signature is the driving (primary) side of this context.
 */
class SignOutUseCase(
    private val repository: SessionRepository,
) {
    operator fun invoke(command: SignOutCommand): SignOutResult {
        repository.revoke(command.sessionId)
        return SignOutResult.Success
    }
}
