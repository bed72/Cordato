package com.bed.cordato.features.identity.application.results

import com.bed.cordato.features.identity.domain.errors.UpdateNameError
import com.bed.cordato.features.identity.domain.entities.PersonEntity

/**
 * Outcome of the "update own name" operation: either a [Success] carrying the updated [PersonEntity] (its
 * public view), or a [Failure] with the domain [UpdateNameError]. Sealed so consumers handle every case in
 * an exhaustive `when`, with no thrown errors.
 */
sealed interface UpdateNameResult {
    data class Failure(val error: UpdateNameError) : UpdateNameResult
    data class Success(val person: PersonEntity) : UpdateNameResult
}
