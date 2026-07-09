package com.bed.cordato.features.identity.application.driving.use_cases

import com.bed.cordato.features.identity.domain.errors.UpdateNameError
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject

import com.bed.cordato.features.identity.application.driving.results.UpdateNameResult
import com.bed.cordato.features.identity.application.driving.commands.UpdateNameCommand
import com.bed.cordato.features.identity.application.driven.repositories.PersonRepository

/**
 * Updates the authenticated person's own name from the session identity the edge guard already settled.
 *
 * It builds the [NameValueObject] from the raw command name — the value object is the single authority on
 * the invariant, so a rejected name is a domain [UpdateNameError.InvalidName], not a thrown error. It then
 * resolves the **active** person for the `personId` (never re-reading the token or reopening the session);
 * an absent person — never existed, or a race with account deletion left it non-active — is
 * [UpdateNameError.PersonNotFound], which the edge maps to the same neutral `401` a missing session yields.
 * Only the name is persisted (the narrow [PersonRepository.updateName]); a lost race there (the person went
 * non-active between the read and the write) also collapses to [UpdateNameError.PersonNotFound]. On success
 * it returns the updated public view, with only the name changed.
 *
 * The public `invoke` signature is the driving (primary) side of this context.
 */
class UpdateNameUseCase(
    private val repository: PersonRepository,
) {
    operator fun invoke(command: UpdateNameCommand): UpdateNameResult {
        val name = NameValueObject.of(command.name)
            ?: return UpdateNameResult.Failure(UpdateNameError.InvalidName)

        val person = repository.findById(command.personId)
            ?: return UpdateNameResult.Failure(UpdateNameError.PersonNotFound)

        return if (repository.updateName(person.id, name)) {
            UpdateNameResult.Success(person.copy(name = name))
        } else {
            UpdateNameResult.Failure(UpdateNameError.PersonNotFound)
        }
    }
}
