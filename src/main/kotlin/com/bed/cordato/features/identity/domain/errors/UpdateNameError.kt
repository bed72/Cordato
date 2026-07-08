package com.bed.cordato.features.identity.domain.errors

/**
 * Exhaustive set of domain reasons the "update own name" operation can fail. Returned from the use case,
 * never thrown, so the compiler forces every consumer to branch each case.
 *
 * [InvalidName] means the new name does not satisfy the `NameValueObject` invariant (the single authority);
 * the edge maps it to a `422`. [PersonNotFound] mirrors [MeError.PersonNotFound] exactly: a live session
 * pointed at a person who is no longer active — a race with account deletion — carrying no detail, so the
 * edge collapses it into the **same** neutral `401` a missing session yields. A `sealed interface` so the
 * result branches the same exhaustive way the rest of identity does.
 */
sealed interface UpdateNameError {
    data object InvalidName : UpdateNameError

    data object PersonNotFound : UpdateNameError
}
