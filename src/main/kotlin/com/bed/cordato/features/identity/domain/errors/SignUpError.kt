package com.bed.cordato.features.identity.domain.errors

/**
 * Exhaustive set of domain reasons a signup can be rejected. Returned from the use
 * case, never thrown, so the compiler forces every consumer to handle each case.
 *
 * Non-leak invariant: [EmailAlreadyInUse] carries neither the attempted e-mail nor
 * any data about the existing person, so a conflict cannot be used to probe which
 * e-mails are registered. [WeakPassword] may expose the public policy (the minimum
 * length) since that reveals nothing about any specific person.
 */
sealed interface SignUpError {
    data object InvalidName : SignUpError

    data object InvalidEmail : SignUpError

    data object EmailAlreadyInUse : SignUpError

    data class WeakPassword(val minLength: Int) : SignUpError
}
