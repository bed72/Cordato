package com.bed.cordato.core.domain.virtual_objects

/**
 * The generic keyset-pagination slice behind every "list my own X" listing — a **Virtual Object**: a
 * projection assembled on the fly, carrying no identity of its own and never persisted.
 *
 * Construct via [of], which takes `limit + 1` [fetched] items — one more than requested, with no extra
 * `COUNT` — so it can tell whether a next page exists: more than [limit] came back means there is more,
 * so only the first [limit] are kept and [nextCursor] is derived by [cursorOf] from the last **kept**
 * item; otherwise there is nothing more, so [nextCursor] is `null`. Each feature's own listing use case
 * fetches `limit + 1` from its repository and hands the result here; the item type [T] and cursor type [C]
 * stay whatever that feature already uses (e.g. an entity and its own keyset cursor value object).
 */
data class KeysetPageVirtualObject<T, C>(
    val items: List<T>,
    val nextCursor: C?,
) {
    companion object {
        fun <T, C> of(fetched: List<T>, limit: Int, cursorOf: (T) -> C): KeysetPageVirtualObject<T, C> {
            val hasMore = fetched.size > limit
            val items = if (hasMore) fetched.take(limit) else fetched
            val nextCursor = if (hasMore) cursorOf(items.last()) else null

            return KeysetPageVirtualObject(items, nextCursor)
        }
    }
}
