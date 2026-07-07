package com.bed.cordato.features.identity.domain.errors

/**
 * The single domain reason a login can be rejected. Returned from the use case, never thrown.
 *
 * Non-leak invariant: wrong password, unknown e-mail and a non-active person all collapse into
 * this one [InvalidCredentials] with no detail — the refusal never says *which* factor failed, so
 * it cannot be used to probe whether an e-mail is registered. It is a `sealed interface` with a
 * lone case (not a bare `object`) so the login result branches the same exhaustive way signup does,
 * and so a second reason could only ever be added deliberately.
 */
sealed interface SignInError {
    data object InvalidCredentials : SignInError
}
