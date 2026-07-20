package com.bed.cordato.features.expense.infrastructure.http.mappers.requests

import java.util.Base64
import java.time.LocalDate

import com.bed.cordato.features.expense.domain.value_objects.ExpenseCursorValueObject

/**
 * The outcome of decoding the `cursor` query param: absent (first page), a well-formed [cursor], or
 * malformed input the controller must refuse with a `400` — three states a nullable
 * [ExpenseCursorValueObject] alone couldn't tell apart (`null` would mean both "no cursor" and "unreadable
 * cursor"), so this is a small sealed result instead of a thrown exception.
 */
internal sealed class DecodedCursor {
    data object Absent : DecodedCursor()
    data object Malformed : DecodedCursor()
    data class Present(val cursor: ExpenseCursorValueObject) : DecodedCursor()
}

/**
 * Decodes the opaque `cursor` query param back into its typed keyset position — the inverse of
 * [toToken][com.bed.cordato.features.expense.infrastructure.http.mappers.responses.toToken]. The wire format
 * is base64-url of `"<spent_on ISO>|<id>"`; a `null` receiver (the param was absent) maps to [DecodedCursor.Absent],
 * and anything that fails to decode/parse (bad base64, missing separator, unparsable date) maps to
 * [DecodedCursor.Malformed] rather than throwing — the controller turns that into a `400 MALFORMED_REQUEST`,
 * never a `500`.
 */
internal fun String?.toCursor(): DecodedCursor {
    if (this == null) return DecodedCursor.Absent

    return runCatching {
        val decoded = String(Base64.getUrlDecoder().decode(this))
        val (spentOn, id) = decoded.split("|", limit = 2)
        DecodedCursor.Present(ExpenseCursorValueObject.of(LocalDate.parse(spentOn), id))
    }.getOrDefault(DecodedCursor.Malformed)
}
