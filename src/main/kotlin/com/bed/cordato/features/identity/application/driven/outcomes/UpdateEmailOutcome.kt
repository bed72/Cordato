package com.bed.cordato.features.identity.application.driven.outcomes

/**
 * An **outcome**: the enumerated, exhaustive result a driven port ([com.bed.cordato.features.identity.application.driven.repositories.PersonRepository.updateEmail])
 * returns to name which of several mutually-exclusive things happened at the persistence boundary, so the use
 * case can branch over it. It is not a `Result` (that is the use case's answer to the edge), not a domain
 * `Enum` (it describes what the datastore did, not a business rule), and not an `Error` (`UPDATED` is a
 * success). See the "Port outcomes" convention in `CLAUDE.md`.
 *
 * The three authoritative outcomes of persisting a person's new e-mail. Unlike name updates (updated vs.
 * non-active — two states, a `Boolean` suffices), an e-mail update has a **third** outcome: the new e-mail
 * may already belong to another person. A `Boolean` would collapse [EMAIL_TAKEN] and [PERSON_INACTIVE],
 * which the use case maps to different domain errors (a `422` conflict vs. a neutral `401`). A small, pure
 * enum kept in `application` — no framework dependency.
 *
 * [UPDATED] — the active person's e-mail was changed. [EMAIL_TAKEN] — the new e-mail already belongs to
 * another person (a uniqueness conflict decided authoritatively at the datastore, closing the concurrent
 * race). [PERSON_INACTIVE] — no active person matched (never existed, or a race with account deletion left it
 * non-active); zero rows affected.
 */
enum class UpdateEmailOutcome {
    UPDATED,
    EMAIL_TAKEN,
    PERSON_INACTIVE,
}
