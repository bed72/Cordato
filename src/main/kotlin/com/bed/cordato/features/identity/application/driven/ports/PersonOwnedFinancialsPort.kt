package com.bed.cordato.features.identity.application.driven.ports

/**
 * Anti-Corruption Layer port (ADR 0013), in the write direction — the first of its kind in this codebase,
 * every prior instance (`couple → budget`, `couple → expense`) being read-only. The only way `identity`'s
 * application/domain may trigger the removal of a person's owned financial data, phrased entirely in
 * identity's own vocabulary: "delete everything [personId] owns". `identity/domain` and
 * `identity/application` never import anything from `budget` or `expense` beyond this port; neither
 * `budget` nor `expense` knows this port (or identity) exists. Implemented by
 * `identity/infrastructure/adapters/PersonOwnedFinancialsAdapter`, which calls budget's and expense's own
 * public use cases in-process — the adapter, not the port, knows that "everything a person owns" happens to
 * live in two separate contexts today.
 */
fun interface PersonOwnedFinancialsPort {
    operator fun invoke(personId: String)
}
