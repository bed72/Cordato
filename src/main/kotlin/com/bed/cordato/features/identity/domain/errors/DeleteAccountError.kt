package com.bed.cordato.features.identity.domain.errors

/**
 * Exhaustive set of domain reasons the "delete own account" operation can fail. Returned from the use case,
 * never thrown, so the compiler forces every consumer to branch each case.
 *
 * [InvalidCredentials] (the confirmation password did not match) and [PersonNotFound] (a live session
 * pointed at a person no longer active — a race with a concurrent deletion) both carry no detail, so the
 * edge collapses **both** into the **same** neutral `401` a missing/invalid token yields —
 * indistinguishable from each other and from an absent session, the same posture
 * [com.bed.cordato.features.identity.domain.errors.UpdatePasswordError] already takes. A `sealed interface`
 * so the result branches the same exhaustive way the rest of identity does.
 */
sealed interface DeleteAccountError {
    data object PersonNotFound : DeleteAccountError
    data object InvalidCredentials : DeleteAccountError
}
