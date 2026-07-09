package com.bed.cordato.features.identity.domain.errors

/**
 * Exhaustive set of domain reasons the "update own e-mail" operation can fail. Returned from the use case,
 * never thrown, so the compiler forces every consumer to branch each case.
 *
 * [InvalidEmail] means the new e-mail does not satisfy the `EmailValueObject` invariant (the single
 * authority); the edge maps it to a neutral `422`. [EmailAlreadyInUse] means the new e-mail already belongs
 * to **another** person — it carries neither the attempted e-mail nor any data about the existing person, so
 * a conflict cannot be used to probe which e-mails are registered (the same non-leak posture as signup); the
 * edge maps it to a generic, scalar `422` — never a `FieldError(field="email")` nor a distinct status.
 * [InvalidCredentials] (the confirmation password did not match) and [PersonNotFound] (a live session pointed
 * at a person who is no longer active — a race with account deletion) both carry no detail, so the edge
 * collapses **both** into the **same** neutral `401` a missing/invalid token yields — indistinguishable from
 * each other and from an absent session. A `sealed interface` so the result branches the same exhaustive way
 * the rest of identity does.
 */
sealed interface UpdateEmailError {
    data object InvalidEmail : UpdateEmailError

    data object EmailAlreadyInUse : UpdateEmailError

    data object InvalidCredentials : UpdateEmailError

    data object PersonNotFound : UpdateEmailError
}
