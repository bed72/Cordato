package com.bed.cordato.features.expense.infrastructure.http.mappers.responses

import java.util.Base64

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.domain.value_objects.ExpenseCursorValueObject
import com.bed.cordato.features.expense.domain.virtual_objects.ExpensePageVirtualObject
import com.bed.cordato.features.expense.infrastructure.http.responses.ExpenseResponse
import com.bed.cordato.features.expense.infrastructure.http.responses.ExpensePageResponse

/**
 * Projects a created [ExpenseEntity] into its public [ExpenseResponse], as an `internal` extension
 * (`expense.toResponse()`). It unwraps the value objects to their wire types — the amount to its integer
 * cents, the date to its `LocalDate`, the optional description to its string (or null) — and carries no
 * budget reference, mirroring the entity.
 */
internal fun ExpenseEntity.toResponse(): ExpenseResponse = ExpenseResponse(
    id = id,
    date = date.value,
    amountInCents = amount.cents,
    description = description?.value,
)

/**
 * Projects an [ExpensePageVirtualObject] into the public envelope: each item through
 * [ExpenseEntity.toResponse], and the keyset [ExpensePageVirtualObject.nextCursor] — when present — encoded
 * back into its opaque wire token via [toToken].
 */
internal fun ExpensePageVirtualObject.toResponse(): ExpensePageResponse = ExpensePageResponse(
    items = items.map { it.toResponse() },
    nextCursor = nextCursor?.toToken(),
)

/**
 * Encodes a keyset position into the opaque `cursor` string the client only ever echoes back — base64-url
 * of `"<spent_on ISO>|<id>"`. The inverse of
 * [toCursor][com.bed.cordato.features.expense.infrastructure.http.mappers.requests.toCursor].
 */
internal fun ExpenseCursorValueObject.toToken(): String =
    Base64.getUrlEncoder().withoutPadding().encodeToString("$spentOn|$id".toByteArray())
