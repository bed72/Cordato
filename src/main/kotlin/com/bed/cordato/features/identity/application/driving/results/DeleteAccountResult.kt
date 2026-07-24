package com.bed.cordato.features.identity.application.driving.results

import com.bed.cordato.features.identity.domain.errors.DeleteAccountError

/**
 * Outcome of the "delete own account" operation: [Success] carries no payload — unlike the other
 * `person-profile` mutations, there is no updated public view to return, since the account (and the
 * session that just made the call) no longer exist. [Failure] carries the domain [DeleteAccountError].
 * Sealed so consumers handle every case in an exhaustive `when`, with no thrown errors.
 */
sealed interface DeleteAccountResult {
    data object Success : DeleteAccountResult
    data class Failure(val error: DeleteAccountError) : DeleteAccountResult
}
