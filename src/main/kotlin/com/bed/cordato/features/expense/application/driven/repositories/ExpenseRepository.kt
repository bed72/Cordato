package com.bed.cordato.features.expense.application.driven.repositories

import java.time.LocalDate

import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.domain.value_objects.ExpenseCursorValueObject

/**
 * Driven port for expense persistence, seen by the application. Implemented in infrastructure.
 *
 * [create] persists a fully-built [ExpenseEntity]. It returns `Unit`: registering an expense has no
 * caller-relevant alternative outcome — there is no uniqueness constraint to collide with and no "already
 * exists" state — so a `Boolean`/`Outcome` would invent a distinction that doesn't exist. A datastore
 * failure surfaces as an infrastructure exception, never crossing back into the application as a value.
 *
 * [findByPerson] returns a **keyset** slice of the expenses owned by [personId]: at most [limit] items,
 * strictly after [after] when given (the first slice when `null`), as a [List] (empty when there is nothing
 * past that position — never `null`, never an error). Listing one's own expenses has no domain failure
 * branch: absence is a normal, empty success. The order is the adapter's concern (deterministic: most
 * recent first, `(spent_on, id)` desc — the same tuple [after] positions against); the application only
 * relies on it being stable. The port knows nothing of an opaque wire cursor or a response envelope — only
 * the typed keyset position and the limit.
 *
 * [sumAmountInRange] answers the total, in cents, of [personId]'s expenses whose date falls within
 * `[startDate, endDate]` (both included) — resolved entirely in the datastore (`SUM` with `COALESCE` to
 * `0`), never by loading rows to sum in memory. This is one of the two aggregate questions `expense`
 * answers about its own data to anyone outside (today, `budget`, through its own ACL) — never an individual
 * expense nor the list of them. A person with nothing in range yields `0`, not an error.
 *
 * [sumAmount] answers the total, in cents, of **all** of [personId]'s expenses, with no date limit — same
 * resolution posture as [sumAmountInRange] (`SUM`/`COALESCE` in the datastore, never in memory). A person
 * with no expenses at all yields `0`, not an error.
 *
 * [deleteAllOwnedBy] **physically removes** every expense row of [personId] — the first delete capability
 * `expense` gets at all. It exists solely to serve `identity`'s account-deletion cascade (ADR-0013). A
 * person with no expenses is a silent no-op, not an error; a datastore failure surfaces as an infrastructure
 * exception, the same posture as [create].
 */
interface ExpenseRepository {
    fun create(expense: ExpenseEntity)

    fun sumAmount(personId: String): Long

    fun deleteAllOwnedBy(personId: String)

    fun sumAmountInRange(personId: String, startDate: LocalDate, endDate: LocalDate): Long

    fun findByPerson(personId: String, after: ExpenseCursorValueObject?, limit: Int): List<ExpenseEntity>
}
