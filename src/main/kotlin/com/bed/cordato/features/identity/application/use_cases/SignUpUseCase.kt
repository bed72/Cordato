package com.bed.cordato.features.identity.application.use_cases

import com.bed.cordato.core.application.ports.IdGeneratorPort

import com.bed.cordato.features.identity.domain.errors.SignUpError
import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum

import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.domain.value_objects.PasswordValueObject

import com.bed.cordato.features.identity.application.results.SignUpResult
import com.bed.cordato.features.identity.application.commands.SignUpCommand
import com.bed.cordato.features.identity.application.ports.PasswordHasherPort
import com.bed.cordato.features.identity.application.repositories.PersonRepository

/**
 * Registers a new person. Order is deliberate: validate each input (fail-fast,
 * e-mail first), then check e-mail uniqueness *before* hashing so a doomed signup
 * never pays the hashing cost, then hash, build the active person, and persist.
 *
 * The public `invoke` signature is the driving (primary) side of this context — no
 * extra interface is added for it.
 */
class SignUpUseCase(
    private val generator: IdGeneratorPort,
    private val hasher: PasswordHasherPort,
    private val repository: PersonRepository,
) {
    operator fun invoke(command: SignUpCommand): SignUpResult {
        val email = EmailValueObject.of(command.email)
            ?: return SignUpResult.Failure(SignUpError.InvalidEmail)

        val name = NameValueObject.of(command.name)
            ?: return SignUpResult.Failure(SignUpError.InvalidName)

        val password = PasswordValueObject.of(command.password)
            ?: return SignUpResult.Failure(SignUpError.WeakPassword(PasswordValueObject.MIN_LENGTH))

        if (repository.existsByEmail(email)) {
            return SignUpResult.Failure(SignUpError.EmailAlreadyInUse)
        }

        val person = PersonEntity(
            name = name,
            email = email,
            id = generator.invoke(),
            hash = hasher.hash(password),
            status = PersonStatusEnum.ACTIVE,
        )
        repository.save(person)

        return SignUpResult.Success(person)
    }
}
