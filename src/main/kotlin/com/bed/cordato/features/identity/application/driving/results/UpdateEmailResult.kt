package com.bed.cordato.features.identity.application.driving.results

import com.bed.cordato.features.identity.domain.errors.UpdateEmailError
import com.bed.cordato.features.identity.domain.entities.PersonEntity

/**
 * Outcome of the "update own e-mail" operation: either a [Success] carrying the updated [PersonEntity] (its
 * public view, with only the e-mail changed), or a [Failure] with the domain [UpdateEmailError]. Sealed so
 * consumers handle every case in an exhaustive `when`, with no thrown errors.
 */
sealed interface UpdateEmailResult {
    data class Failure(val error: UpdateEmailError) : UpdateEmailResult
    data class Success(val person: PersonEntity) : UpdateEmailResult
}
