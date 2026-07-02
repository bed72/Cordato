package com.bed.cordato.features.identity.application.results

import com.bed.cordato.features.identity.domain.errors.SignUpError
import com.bed.cordato.features.identity.domain.entities.PersonEntity

/**
 * Outcome of a signup: either the created [PersonEntity] or a domain [SignUpError].
 * Sealed so consumers must handle every case in an exhaustive `when`, with no thrown
 * errors.
 */
sealed interface SignUpResult {
    data class Failure(val error: SignUpError) : SignUpResult
    data class Success(val person: PersonEntity) : SignUpResult
}
