package com.bed.cordato.features.identity.application.driving.results

/**
 * Outcome of the `SignOut` operation: a single [Success] case — there is no domain error to branch on, since
 * the session id comes from the edge guard's own resolution and revoking an already-gone session is still a
 * valid, client-visible success. Kept as a one-case sealed type only for symmetry with every other identity
 * use case's result type.
 */
sealed interface SignOutResult {
    data object Success : SignOutResult
}
