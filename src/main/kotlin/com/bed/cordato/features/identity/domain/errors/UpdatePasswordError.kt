package com.bed.cordato.features.identity.domain.errors

/**
 * Exhaustive set of domain reasons the "update own password" operation can fail. Returned from the use case,
 * never thrown, so the compiler forces every consumer to branch each case.
 *
 * [WeakPassword] means the new password does not satisfy the `PasswordValueObject` policy (the single
 * authority) — a **public** rule (the minimum length reveals nothing about any person), so the edge may map
 * it to a specific `422`. [SamePassword] means the new password, though valid, equals the person's current
 * password — since it is the authenticated owner's own secret, a specific "must differ" message is no
 * account-discovery oracle, so the edge maps it to a specific `422` as well; both public rejections share the
 * same status so the status line never signals which occurred. [InvalidCredentials] (the confirmation
 * password did not match) and [PersonNotFound] (a live session pointed at a person no longer active — a race
 * with account deletion) both carry no detail, so the edge collapses **both** into the **same** neutral `401`
 * a missing/invalid token yields — indistinguishable from each other and from an absent session. A
 * `sealed interface` so the result branches the same exhaustive way the rest of identity does.
 */
sealed interface UpdatePasswordError {
    data object WeakPassword : UpdatePasswordError
    data object SamePassword : UpdatePasswordError
    data object PersonNotFound : UpdatePasswordError
    data object InvalidCredentials : UpdatePasswordError
}
