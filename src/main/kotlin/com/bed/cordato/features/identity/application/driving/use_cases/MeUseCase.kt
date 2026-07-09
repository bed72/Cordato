package com.bed.cordato.features.identity.application.driving.use_cases

import com.bed.cordato.features.identity.domain.errors.MeError

import com.bed.cordato.features.identity.application.driving.results.MeResult
import com.bed.cordato.features.identity.application.driving.commands.MeCommand
import com.bed.cordato.features.identity.application.driven.repositories.PersonRepository

/**
 * Resolves the authenticated person's public view from the session identity the edge guard already settled.
 *
 * It receives the `personId` (via [MeCommand]) and only resolves the **active** person for it — it never
 * re-reads the token or reopens the session, keeping the driving-side separation the filter established. An
 * absent person (never existed, or a race with account deletion left it non-active) is a domain
 * [MeError.PersonNotFound], not a thrown error: the edge maps it to the same neutral `401` a missing session
 * yields, so an orphaned session is indistinguishable from an invalid token.
 *
 * The public `invoke` signature is the driving (primary) side of this context.
 */
class MeUseCase(
    private val repository: PersonRepository,
) {
    operator fun invoke(command: MeCommand): MeResult =
        repository.findById(command.personId)
            ?.let(MeResult::Success)
            ?: MeResult.Failure(MeError.PersonNotFound)
}
