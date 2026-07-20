package com.bed.cordato.core.infrastructure.http.responses

/**
 * Shared pagination defaults for every cursor-paginated listing across bounded contexts — the page size
 * ceiling ([MAX_LIMIT]) and the default applied when the caller's `limit` query param is absent
 * ([DEFAULT_LIMIT]). This is HTTP-transport policy, not a domain rule, so it lives in `core` rather than
 * being duplicated (and potentially drifting) per feature.
 */
object PaginationResponse {
    const val MAX_LIMIT = 100
    const val DEFAULT_LIMIT = 20
}
