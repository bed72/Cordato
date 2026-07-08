package com.bed.cordato.features.identity.application.results

import com.bed.cordato.features.identity.domain.errors.MeError
import com.bed.cordato.features.identity.domain.entities.PersonEntity

/**
 * Outcome of the `Me` operation: either a [Success] carrying the resolved active [PersonEntity], or a
 * [Failure] with the domain [MeError]. Sealed so consumers handle every case in an exhaustive `when`, with
 * no thrown errors.
 */
sealed interface MeResult {
    data class Failure(val error: MeError) : MeResult
    data class Success(val person: PersonEntity) : MeResult
}
