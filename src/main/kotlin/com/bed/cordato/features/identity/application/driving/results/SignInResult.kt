package com.bed.cordato.features.identity.application.driving.results

import com.bed.cordato.core.domain.entities.SessionEntity

import com.bed.cordato.features.identity.domain.errors.SignInError

/**
 * Outcome of a login: either a [Success] carrying the opened [SessionEntity] **and the plaintext
 * token**, or a [Failure] with the domain [SignInError]. Sealed so consumers handle every case in an
 * exhaustive `when`, with no thrown errors.
 *
 * [Success] carries the token in the clear because the persisted session holds only its hash, yet
 * the client needs the token once — it travels from the use case to the response mapper and is never
 * stored or recoverable afterwards.
 */
sealed interface SignInResult {
    data class Failure(val error: SignInError) : SignInResult
    data class Success(val session: SessionEntity, val token: String) : SignInResult
}
