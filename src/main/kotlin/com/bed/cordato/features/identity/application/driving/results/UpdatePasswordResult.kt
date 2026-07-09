package com.bed.cordato.features.identity.application.driving.results

import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.errors.UpdatePasswordError

/**
 * Outcome of the "update own password" operation: either a [Success] carrying the person's public view (its
 * identity is unchanged by a password rotation, but the shape stays uniform with the name/e-mail edits), or a
 * [Failure] with the domain [UpdatePasswordError]. Sealed so consumers handle every case in an exhaustive
 * `when`, with no thrown errors.
 */
sealed interface UpdatePasswordResult {
    data class Success(val person: PersonEntity) : UpdatePasswordResult
    data class Failure(val error: UpdatePasswordError) : UpdatePasswordResult
}
