package com.bed.cordato.features.identity.application.driving.use_cases

import com.bed.cordato.features.identity.domain.errors.UpdateEmailError
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

import com.bed.cordato.features.identity.application.driven.ports.PasswordHasherPort
import com.bed.cordato.features.identity.application.driving.results.UpdateEmailResult
import com.bed.cordato.features.identity.application.driving.commands.UpdateEmailCommand
import com.bed.cordato.features.identity.application.driven.repositories.PersonRepository
import com.bed.cordato.features.identity.application.driven.outcomes.UpdateEmailOutcome

/**
 * Changes the authenticated person's own e-mail from the session identity the edge guard already settled —
 * a step-up operation that confirms the current password before touching anything, mirroring account
 * deletion's confirmation rule.
 *
 * The order is deliberate:
 * 1. Build the [EmailValueObject] from the raw command e-mail — the value object is the single authority on
 *    the invariant, so a rejected e-mail is [UpdateEmailError.InvalidEmail], not a thrown error.
 * 2. Resolve the **active** person for the `personId` (never re-reading the token); an absent person —
 *    never existed, or a race with account deletion left it non-active — is [UpdateEmailError.PersonNotFound],
 *    which the edge maps to the same neutral `401` a missing session yields.
 * 3. Confirm the current password against the stored hash **before** any write; a mismatch is
 *    [UpdateEmailError.InvalidCredentials], mapped to that same neutral `401`.
 * 4. If the new (normalized) e-mail already equals the person's current e-mail, it is a successful idempotent
 *    no-op — not an [UpdateEmailError.EmailAlreadyInUse] conflict — so no write is issued.
 * 5. Persist the e-mail via the narrow, uniqueness-authoritative [PersonRepository.updateEmail] and branch
 *    its outcome: `UPDATED` → the updated public view; `EMAIL_TAKEN` (the e-mail belongs to another person) →
 *    [UpdateEmailError.EmailAlreadyInUse]; `PERSON_INACTIVE` (a lost race with deletion) →
 *    [UpdateEmailError.PersonNotFound].
 *
 * No exception is thrown on any domain path. The public `invoke` signature is the driving (primary) side of
 * this context.
 */
class UpdateEmailUseCase(
    private val hasher: PasswordHasherPort,
    private val repository: PersonRepository,
) {
    operator fun invoke(command: UpdateEmailCommand): UpdateEmailResult {
        val email = EmailValueObject.of(command.email)
            ?: return UpdateEmailResult.Failure(UpdateEmailError.InvalidEmail)

        val person = repository.findById(command.personId)
            ?: return UpdateEmailResult.Failure(UpdateEmailError.PersonNotFound)

        if (!hasher.verify(command.password, person.hash)) {
            return UpdateEmailResult.Failure(UpdateEmailError.InvalidCredentials)
        }

        if (email == person.email) {
            return UpdateEmailResult.Success(person)
        }

        return when (repository.updateEmail(person.id, email)) {
            UpdateEmailOutcome.UPDATED -> UpdateEmailResult.Success(person.copy(email = email))
            UpdateEmailOutcome.EMAIL_TAKEN -> UpdateEmailResult.Failure(UpdateEmailError.EmailAlreadyInUse)
            UpdateEmailOutcome.PERSON_INACTIVE -> UpdateEmailResult.Failure(UpdateEmailError.PersonNotFound)
        }
    }
}
