package com.bed.cordato.features.identity.domain.errors

/**
 * The single domain reason the `Me` operation can fail. Returned from the use case, never thrown.
 *
 * [PersonNotFound] means a live session pointed at a person who is no longer active — a race with account
 * deletion. It carries no detail: the edge collapses it into the **same** neutral `401` a missing session
 * yields, so the refusal never reveals that the session existed but the person did not. A `sealed interface`
 * with a lone case (not a bare `object`) so the result branches the same exhaustive way the rest of identity
 * does, and so a second reason could only ever be added deliberately.
 */
sealed interface MeError {
    data object PersonNotFound : MeError
}
