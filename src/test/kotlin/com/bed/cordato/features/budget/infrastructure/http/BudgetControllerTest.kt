package com.bed.cordato.features.budget.infrastructure.http

import io.mockk.slot
import io.mockk.just
import io.mockk.Runs
import io.mockk.every
import io.mockk.verify
import io.mockk.clearMocks

import jakarta.inject.Inject

import java.time.LocalDate

import kotlin.test.Test
import kotlin.test.BeforeTest
import kotlin.test.assertTrue
import kotlin.test.assertEquals

import io.micronaut.http.MediaType
import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpRequest
import io.micronaut.core.type.Argument
import io.micronaut.http.client.HttpClient
import io.micronaut.http.client.annotation.Client
import io.micronaut.test.extensions.junit5.annotation.MicronautTest
import io.micronaut.http.client.exceptions.HttpClientResponseException

import com.bed.cordato.core.factories.LIVE_TOKEN
import com.bed.cordato.core.factories.SESSION_PERSON_ID
import com.bed.cordato.core.infrastructure.http.responses.DataResponse
import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse

import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

import com.bed.cordato.features.budget.factories.budget

import com.bed.cordato.features.budget.domain.entities.BudgetEntity
import com.bed.cordato.features.budget.domain.enums.BudgetStatusEnum
import com.bed.cordato.features.budget.domain.value_objects.NoteValueObject
import com.bed.cordato.features.budget.infrastructure.http.responses.BudgetResponse
import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository
import com.bed.cordato.features.budget.infrastructure.http.responses.ActiveBudgetResponse
import com.bed.cordato.features.budget.infrastructure.http.responses.DefaultBudgetResponse

private const val DEAD_TOKEN = "dead-token"

/**
 * End-to-end cover of `POST /budgets`, `PATCH /budgets/{id}`, `DELETE /budgets/{id}`, `GET /budgets/active`
 * and `GET /budgets/default` through the edge guard (filter + binder), the edge Bean Validation, the
 * **real** use cases, and the neutral error contract. Only the [BudgetRepository] and expense's
 * [ExpenseRepository] are doubles (wired globally by
 * [com.bed.cordato.features.budget.factories.BudgetRepositoryMockFactory] and
 * [com.bed.cordato.features.expense.factories.ExpenseRepositoryMockFactory]), so the whole
 * route→use-case→ACL-adapter→expense-use-case path runs; the fake session repository (wired globally)
 * resolves only [LIVE_TOKEN] to [SESSION_PERSON_ID]. `hasOverlappingLiveBudget` defaults to `false` so a
 * plain valid request succeeds; the `422 OVERLAPPING_BUDGET` path stubs it to `true`. `sumAmountInRange`
 * defaults to `0` so a plain active-budget request has no spending.
 */
@MicronautTest
internal class BudgetControllerTest {

    @Inject
    lateinit var budgetRepository: BudgetRepository

    @Inject
    lateinit var expenseRepository: ExpenseRepository

    @Inject
    @field:Client("/")
    lateinit var client: HttpClient

    @BeforeTest
    fun reset() {
        clearMocks(budgetRepository)
        clearMocks(expenseRepository)
        every { expenseRepository.sumAmount(any()) } returns 0
        every { budgetRepository.findAllLiveBudgets(any()) } returns emptyList()
        every { expenseRepository.sumAmountInRange(any(), any(), any()) } returns 0
        every { budgetRepository.hasOverlappingLiveBudget(any(), any(), any(), any()) } returns false
    }

    private fun post(body: Any, authorization: String? = null): HttpRequest<Any> {
        val request = HttpRequest.POST<Any>("/v1/budgets", body)
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun getActive(authorization: String? = null): HttpRequest<Any> {
        val request = HttpRequest.GET<Any>("/v1/budgets/active")
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun getDefault(authorization: String? = null): HttpRequest<Any> {
        val request = HttpRequest.GET<Any>("/v1/budgets/default")
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun patch(id: String, body: Any, authorization: String? = null): HttpRequest<Any> {
        val request = HttpRequest.PATCH<Any>("/v1/budgets/$id", body)
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun delete(id: String, authorization: String? = null): HttpRequest<Any> {
        val request = HttpRequest.DELETE<Any>("/v1/budgets/$id")
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun reject(body: Any, authorization: String? = null): HttpClientResponseException =
        try {
            client.toBlocking().exchange(post(body, authorization), String::class.java)
            error("Expected the request to be refused with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    private fun rejectPatch(id: String, body: Any, authorization: String? = null): HttpClientResponseException =
        try {
            client.toBlocking().exchange(patch(id, body, authorization), String::class.java)
            error("Expected the request to be refused with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    private fun rejectDelete(id: String, authorization: String? = null): HttpClientResponseException =
        try {
            client.toBlocking().exchange(delete(id, authorization), String::class.java)
            error("Expected the request to be refused with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    private fun rejectGetActive(authorization: String? = null): HttpClientResponseException =
        try {
            client.toBlocking().exchange(getActive(authorization), String::class.java)
            error("Expected the request to be refused with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    private fun rejectGetDefault(authorization: String? = null): HttpClientResponseException =
        try {
            client.toBlocking().exchange(getDefault(authorization), String::class.java)
            error("Expected the request to be refused with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    @Test
    fun `an authenticated valid request creates the budget and returns 201`() {
        val persisted = slot<BudgetEntity>()
        every { budgetRepository.create(capture(persisted)) } just Runs

        val response = client.toBlocking().exchange(
            post(
                mapOf(
                    "note" to "  Viagem  ",
                    "end_date" to "2026-07-31",
                    "start_date" to "2026-07-01",
                    "amount_in_cents" to 100_000,
                ),
                "Bearer $LIVE_TOKEN",
            ),
            Argument.of(DataResponse::class.java, BudgetResponse::class.java),
        )

        assertEquals(HttpStatus.CREATED, response.status)
        val body = response.body()!!.data as BudgetResponse
        verify(exactly = 1) { budgetRepository.create(any()) }
        assertEquals("Viagem", body.note)
        assertEquals(100_000, body.amountInCents)
        assertEquals(body.id, persisted.captured.id)
        assertEquals(SESSION_PERSON_ID, persisted.captured.personId)
        assertEquals(LocalDate.of(2026, 7, 31), body.endDate)
        assertEquals(LocalDate.of(2026, 7, 1), body.startDate)
    }

    @Test
    fun `an absent note creates a budget without one`() {
        val persisted = slot<BudgetEntity>()
        every { budgetRepository.create(capture(persisted)) } just Runs

        val response = client.toBlocking().exchange(
            post(
                mapOf("amount_in_cents" to 50_000, "start_date" to "2026-07-01", "end_date" to "2026-07-10"),
                "Bearer $LIVE_TOKEN",
            ),
            Argument.of(DataResponse::class.java, BudgetResponse::class.java),
        )

        assertEquals(HttpStatus.CREATED, response.status)
        assertEquals(null, (response.body()!!.data as BudgetResponse).note)
    }

    @Test
    fun `no token is refused with a neutral 401 before the use case runs`() {
        val exception = reject(
            mapOf("amount_in_cents" to 100_000, "start_date" to "2026-07-01", "end_date" to "2026-07-31"),
        )

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals(null, item.source)
        verify(exactly = 0) { budgetRepository.create(any()) }
        assertEquals("UNAUTHENTICATED", item.code)
    }

    @Test
    fun `an unresolvable token is refused with a neutral 401 before the use case runs`() {
        val exception = reject(mapOf("amount_in_cents" to 100_000), "Bearer $DEAD_TOKEN")

        verify(exactly = 0) { budgetRepository.create(any()) }
        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        assertEquals("UNAUTHENTICATED", exception.response.getBody(ErrorsResponse::class.java).get().errors.single().code)
    }

    @Test
    fun `a missing amount fails edge validation with 400 per field without persisting`() {
        val exception = reject(
            mapOf("start_date" to "2026-07-01", "end_date" to "2026-07-31"),
            "Bearer $LIVE_TOKEN",
        )

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val errors = exception.response.getBody(ErrorsResponse::class.java).get().errors
        verify(exactly = 0) { budgetRepository.create(any()) }
        assertEquals(setOf("amountInCents"), errors.mapNotNull { it.source?.field }.toSet())
    }

    @Test
    fun `a non-positive amount fails edge validation with 400 per field without persisting`() {
        val exception = reject(
            mapOf("amount_in_cents" to 0, "start_date" to "2026-07-01", "end_date" to "2026-07-31"),
            "Bearer $LIVE_TOKEN",
        )

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val errors = exception.response.getBody(ErrorsResponse::class.java).get().errors
        verify(exactly = 0) { budgetRepository.create(any()) }
        assertTrue(errors.any { it.source?.field == "amountInCents" }, "$errors")
    }

    @Test
    fun `missing dates fail edge validation with 400 per field without persisting`() {
        val exception = reject(mapOf("amount_in_cents" to 100_000), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val errors = exception.response.getBody(ErrorsResponse::class.java).get().errors
        verify(exactly = 0) { budgetRepository.create(any()) }
        assertEquals(setOf("startDate", "endDate"), errors.mapNotNull { it.source?.field }.toSet())
    }

    @Test
    fun `an over-length note fails edge validation with 400 without persisting`() {
        val tooLong = "a".repeat(NoteValueObject.MAX_LENGTH + 1)

        val exception = reject(
            mapOf(
                "note" to tooLong,
                "end_date" to "2026-07-31",
                "start_date" to "2026-07-01",
                "amount_in_cents" to 100_000,
            ),
            "Bearer $LIVE_TOKEN",
        )

        verify(exactly = 0) { budgetRepository.create(any()) }
        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        assertEquals("INVALID_REQUEST", exception.response.getBody(ErrorsResponse::class.java).get().errors.single().code)
    }

    @Test
    fun `a malformed body is rejected with a scalar 400 without persisting`() {
        val request = HttpRequest.POST("/v1/budgets", "not-json")
            .contentType(MediaType.APPLICATION_JSON)
            .header("Authorization", "Bearer $LIVE_TOKEN")

        val exception = try {
            client.toBlocking().exchange(request, String::class.java)
            error("Expected the request to be refused")
        } catch (exception: HttpClientResponseException) {
            exception
        }

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals(null, item.source)
        verify(exactly = 0) { budgetRepository.create(any()) }
        assertEquals("MALFORMED_REQUEST", item.code)
    }

    @Test
    fun `an end date before the start date is rejected by the domain with a scalar 422 without persisting`() {
        val exception = reject(
            mapOf("amount_in_cents" to 100_000, "start_date" to "2026-07-15", "end_date" to "2026-07-14"),
            "Bearer $LIVE_TOKEN",
        )

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals(null, item.source)
        verify(exactly = 0) { budgetRepository.create(any()) }
        assertEquals("INVALID_PERIOD", item.code)
    }

    @Test
    fun `a period overlapping another live budget is rejected by the domain with a scalar 422 without persisting`() {
        every { budgetRepository.hasOverlappingLiveBudget(SESSION_PERSON_ID, any(), any()) } returns true

        val exception = reject(
            mapOf("amount_in_cents" to 100_000, "start_date" to "2026-07-01", "end_date" to "2026-07-15"),
            "Bearer $LIVE_TOKEN",
        )

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals(null, item.source)
        verify(exactly = 0) { budgetRepository.create(any()) }
        assertEquals("OVERLAPPING_BUDGET", item.code)
    }

    @Test
    fun `adjacent intervals with no overlap are accepted and return 201`() {
        every { budgetRepository.create(any()) } just Runs

        val response = client.toBlocking().exchange(
            post(
                mapOf("amount_in_cents" to 100_000, "start_date" to "2026-07-16", "end_date" to "2026-07-31"),
                "Bearer $LIVE_TOKEN",
            ),
            Argument.of(DataResponse::class.java, BudgetResponse::class.java),
        )

        verify(exactly = 1) { budgetRepository.create(any()) }
        assertEquals(HttpStatus.CREATED, response.status)
    }

    @Test
    fun `an authenticated valid PATCH updates the budget and returns 200`() {
        every { budgetRepository.findById("budget-1") } returns budget(id = "budget-1", personId = SESSION_PERSON_ID)
        every { budgetRepository.update(any()) } just Runs

        val response = client.toBlocking().exchange(
            patch(
                "budget-1",
                mapOf(
                    "note" to "Editada",
                    "end_date" to "2026-08-10",
                    "start_date" to "2026-08-01",
                    "amount_in_cents" to 50_000,
                ),
                "Bearer $LIVE_TOKEN",
            ),
            Argument.of(DataResponse::class.java, BudgetResponse::class.java),
        )

        assertEquals(HttpStatus.OK, response.status)
        val body = response.body()!!.data as BudgetResponse
        verify(exactly = 1) { budgetRepository.update(any()) }
        assertEquals("Editada", body.note)
        assertEquals(50_000, body.amountInCents)
        assertEquals(LocalDate.of(2026, 8, 1), body.startDate)
        assertEquals(LocalDate.of(2026, 8, 10), body.endDate)
    }

    @Test
    fun `PATCH with no token is refused with a neutral 401 before the use case runs`() {
        val exception = rejectPatch(
            "budget-1",
            mapOf("amount_in_cents" to 100_000, "start_date" to "2026-07-01", "end_date" to "2026-07-31"),
        )

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        assertEquals("UNAUTHENTICATED", exception.response.getBody(ErrorsResponse::class.java).get().errors.single().code)
        verify(exactly = 0) { budgetRepository.update(any()) }
    }

    @Test
    fun `a missing amount fails PATCH edge validation with 400 per field without persisting`() {
        val exception = rejectPatch(
            "budget-1",
            mapOf("start_date" to "2026-07-01", "end_date" to "2026-07-31"),
            "Bearer $LIVE_TOKEN",
        )

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val errors = exception.response.getBody(ErrorsResponse::class.java).get().errors
        verify(exactly = 0) { budgetRepository.update(any()) }
        assertEquals(setOf("amountInCents"), errors.mapNotNull { it.source?.field }.toSet())
    }

    @Test
    fun `a non-positive amount is rejected by the domain with a scalar 422 without persisting`() {
        every { budgetRepository.findById("budget-1") } returns budget(id = "budget-1", personId = SESSION_PERSON_ID)

        val exception = rejectPatch(
            "budget-1",
            mapOf("amount_in_cents" to 0, "start_date" to "2026-07-01", "end_date" to "2026-07-31"),
            "Bearer $LIVE_TOKEN",
        )

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        verify(exactly = 0) { budgetRepository.update(any()) }
    }

    @Test
    fun `PATCH with an end date before the start date is rejected by the domain with a scalar 422 without persisting`() {
        every { budgetRepository.findById("budget-1") } returns budget(id = "budget-1", personId = SESSION_PERSON_ID)

        val exception = rejectPatch(
            "budget-1",
            mapOf("amount_in_cents" to 100_000, "start_date" to "2026-07-15", "end_date" to "2026-07-14"),
            "Bearer $LIVE_TOKEN",
        )

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals(null, item.source)
        verify(exactly = 0) { budgetRepository.update(any()) }
        assertEquals("INVALID_PERIOD", item.code)
    }

    @Test
    fun `an over-length note is rejected by the domain with a scalar 422 without persisting`() {
        every { budgetRepository.findById("budget-1") } returns budget(id = "budget-1", personId = SESSION_PERSON_ID)
        val tooLong = "a".repeat(NoteValueObject.MAX_LENGTH + 1)

        val exception = rejectPatch(
            "budget-1",
            mapOf(
                "note" to tooLong,
                "end_date" to "2026-07-31",
                "start_date" to "2026-07-01",
                "amount_in_cents" to 100_000,
            ),
            "Bearer $LIVE_TOKEN",
        )

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        verify(exactly = 0) { budgetRepository.update(any()) }
    }

    @Test
    fun `PATCH with a period overlapping another live budget is rejected by the domain with a scalar 422 without persisting`() {
        every { budgetRepository.findById("budget-1") } returns budget(id = "budget-1", personId = SESSION_PERSON_ID)
        every { budgetRepository.hasOverlappingLiveBudget(SESSION_PERSON_ID, any(), any(), "budget-1") } returns true

        val exception = rejectPatch(
            "budget-1",
            mapOf("amount_in_cents" to 100_000, "start_date" to "2026-07-01", "end_date" to "2026-07-15"),
            "Bearer $LIVE_TOKEN",
        )

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals(null, item.source)
        verify(exactly = 0) { budgetRepository.update(any()) }
        assertEquals("OVERLAPPING_BUDGET", item.code)
    }

    @Test
    fun `PATCH of an unknown budget id is refused with a scalar 404`() {
        every { budgetRepository.findById("unknown") } returns null

        val exception = rejectPatch(
            "unknown",
            mapOf("amount_in_cents" to 100_000, "start_date" to "2026-07-01", "end_date" to "2026-07-31"),
            "Bearer $LIVE_TOKEN",
        )

        assertEquals(HttpStatus.NOT_FOUND, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals(null, item.source)
        verify(exactly = 0) { budgetRepository.update(any()) }
        assertEquals("BUDGET_NOT_FOUND", item.code)
    }

    @Test
    fun `PATCH of a budget owned by another person is refused with the same scalar 404`() {
        every { budgetRepository.findById("budget-1") } returns budget(id = "budget-1", personId = "another-person")

        val exception = rejectPatch(
            "budget-1",
            mapOf("amount_in_cents" to 100_000, "start_date" to "2026-07-01", "end_date" to "2026-07-31"),
            "Bearer $LIVE_TOKEN",
        )

        assertEquals(HttpStatus.NOT_FOUND, exception.status)
        assertEquals("BUDGET_NOT_FOUND", exception.response.getBody(ErrorsResponse::class.java).get().errors.single().code)
        verify(exactly = 0) { budgetRepository.update(any()) }
    }

    @Test
    fun `PATCH of an already removed budget is refused with the same scalar 404`() {
        every { budgetRepository.findById("budget-1") } returns budget(id = "budget-1", personId = SESSION_PERSON_ID, status = BudgetStatusEnum.DELETED)

        val exception = rejectPatch(
            "budget-1",
            mapOf("amount_in_cents" to 100_000, "start_date" to "2026-07-01", "end_date" to "2026-07-31"),
            "Bearer $LIVE_TOKEN",
        )

        assertEquals(HttpStatus.NOT_FOUND, exception.status)
        assertEquals("BUDGET_NOT_FOUND", exception.response.getBody(ErrorsResponse::class.java).get().errors.single().code)
        verify(exactly = 0) { budgetRepository.update(any()) }
    }

    @Test
    fun `an authenticated DELETE removes the budget and returns 200 with the removed state`() {
        every { budgetRepository.delete("budget-1", SESSION_PERSON_ID) } returns true
        every { budgetRepository.findById("budget-1") } returns budget(id = "budget-1", personId = SESSION_PERSON_ID, status = BudgetStatusEnum.DELETED)

        val response = client.toBlocking().exchange(
            delete("budget-1", "Bearer $LIVE_TOKEN"),
            Argument.of(DataResponse::class.java, BudgetResponse::class.java),
        )

        assertEquals(HttpStatus.OK, response.status)
        assertEquals("budget-1", (response.body()!!.data as BudgetResponse).id)
        verify(exactly = 1) { budgetRepository.delete("budget-1", SESSION_PERSON_ID) }
    }

    @Test
    fun `DELETE with no token is refused with a neutral 401 before the use case runs`() {
        val exception = rejectDelete("budget-1")

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        verify(exactly = 0) { budgetRepository.delete(any(), any()) }
        assertEquals("UNAUTHENTICATED", exception.response.getBody(ErrorsResponse::class.java).get().errors.single().code)
    }

    @Test
    fun `DELETE of an unknown budget id is refused with a scalar 404`() {
        every { budgetRepository.delete("unknown", SESSION_PERSON_ID) } returns false

        val exception = rejectDelete("unknown", "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.NOT_FOUND, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals(null, item.source)
        assertEquals("BUDGET_NOT_FOUND", item.code)
    }

    @Test
    fun `DELETE of a budget owned by another person is refused with the same scalar 404`() {
        every { budgetRepository.delete("budget-1", SESSION_PERSON_ID) } returns false

        val exception = rejectDelete("budget-1", "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.NOT_FOUND, exception.status)
        assertEquals("BUDGET_NOT_FOUND", exception.response.getBody(ErrorsResponse::class.java).get().errors.single().code)
    }

    @Test
    fun `DELETE of an already removed budget is refused with the same scalar 404`() {
        every { budgetRepository.delete("budget-1", SESSION_PERSON_ID) } returns false

        val exception = rejectDelete("budget-1", "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.NOT_FOUND, exception.status)
        assertEquals("BUDGET_NOT_FOUND", exception.response.getBody(ErrorsResponse::class.java).get().errors.single().code)
    }

    @Test
    fun `after a successful DELETE, GET budgets active no longer finds it`() {
        every { budgetRepository.delete("budget-1", SESSION_PERSON_ID) } returns true
        every { budgetRepository.findById("budget-1") } returns budget(id = "budget-1", personId = SESSION_PERSON_ID, status = BudgetStatusEnum.DELETED)
        client.toBlocking().exchange(delete("budget-1", "Bearer $LIVE_TOKEN"), Argument.of(DataResponse::class.java))

        every { budgetRepository.findLiveBudgetCovering(SESSION_PERSON_ID, any()) } returns null

        val response = client.toBlocking().exchange(getActive("Bearer $LIVE_TOKEN"), Argument.of(DataResponse::class.java))

        assertEquals(null, response.body()!!.data)
        assertEquals(HttpStatus.OK, response.status)
    }

    @Test
    fun `after a successful DELETE, a new overlapping budget can be created without error`() {
        every { budgetRepository.delete("budget-1", SESSION_PERSON_ID) } returns true
        every { budgetRepository.findById("budget-1") } returns budget(id = "budget-1", personId = SESSION_PERSON_ID, status = BudgetStatusEnum.DELETED)
        client.toBlocking().exchange(delete("budget-1", "Bearer $LIVE_TOKEN"), Argument.of(DataResponse::class.java))

        every { budgetRepository.create(any()) } just Runs

        val response = client.toBlocking().exchange(
            post(
                mapOf("amount_in_cents" to 100_000, "start_date" to "2026-07-01", "end_date" to "2026-07-31"),
                "Bearer $LIVE_TOKEN",
            ),
            Argument.of(DataResponse::class.java, BudgetResponse::class.java),
        )

        assertEquals(HttpStatus.CREATED, response.status)
    }

    @Test
    fun `an authenticated request with an active budget returns 200 with amount, spent and remaining`() {
        every { budgetRepository.findLiveBudgetCovering(SESSION_PERSON_ID, any()) } returns budget(
            id = "budget-1",
            amountInCents = 100_000,
            personId = SESSION_PERSON_ID,
            endDate = LocalDate.of(2026, 7, 31),
            startDate = LocalDate.of(2026, 7, 1),
        )
        every { expenseRepository.sumAmountInRange(SESSION_PERSON_ID, LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 31)) } returns 45_000

        val response = client.toBlocking().exchange(
            getActive("Bearer $LIVE_TOKEN"),
            Argument.of(DataResponse::class.java, ActiveBudgetResponse::class.java),
        )

        assertEquals(HttpStatus.OK, response.status)
        val body = response.body()!!.data as ActiveBudgetResponse
        assertEquals("budget-1", body.id)
        assertEquals(45_000, body.spentInCents)
        assertEquals(100_000, body.amountInCents)
        assertEquals(55_000, body.remainingInCents)
    }

    @Test
    fun `an active budget with no expenses returns 200 with a zero spent amount`() {
        every { budgetRepository.findLiveBudgetCovering(SESSION_PERSON_ID, any()) } returns budget(personId = SESSION_PERSON_ID)

        val response = client.toBlocking().exchange(
            getActive("Bearer $LIVE_TOKEN"),
            Argument.of(DataResponse::class.java, ActiveBudgetResponse::class.java),
        )

        assertEquals(HttpStatus.OK, response.status)
        val body = response.body()!!.data as ActiveBudgetResponse
        assertEquals(0, body.spentInCents)
        assertEquals(100_000, body.remainingInCents)
    }

    @Test
    fun `no active budget returns 200 with data null, never 404`() {
        every { budgetRepository.findLiveBudgetCovering(SESSION_PERSON_ID, any()) } returns null

        val response = client.toBlocking().exchange(getActive("Bearer $LIVE_TOKEN"), Argument.of(DataResponse::class.java))

        assertEquals(null, response.body()!!.data)
        assertEquals(HttpStatus.OK, response.status)
        verify(exactly = 0) { expenseRepository.sumAmountInRange(any(), any(), any()) }
    }

    @Test
    fun `an exceeded active budget returns 200 with a negative remaining amount`() {
        every { budgetRepository.findLiveBudgetCovering(SESSION_PERSON_ID, any()) } returns budget(personId = SESSION_PERSON_ID, amountInCents = 100_000)
        every { expenseRepository.sumAmountInRange(any(), any(), any()) } returns 130_000

        val response = client.toBlocking().exchange(
            getActive("Bearer $LIVE_TOKEN"),
            Argument.of(DataResponse::class.java, ActiveBudgetResponse::class.java),
        )

        assertEquals(HttpStatus.OK, response.status)
        val body = response.body()!!.data as ActiveBudgetResponse
        assertEquals(-30_000, body.remainingInCents)
    }

    @Test
    fun `the spent amount is asked for exactly the active budget's own period, not an arbitrary range`() {
        every { budgetRepository.findLiveBudgetCovering(SESSION_PERSON_ID, any()) } returns budget(
            personId = SESSION_PERSON_ID,
            endDate = LocalDate.of(2026, 7, 20),
            startDate = LocalDate.of(2026, 7, 5),
        )

        client.toBlocking().exchange(getActive("Bearer $LIVE_TOKEN"), Argument.of(DataResponse::class.java))

        verify(exactly = 1) {
            expenseRepository.sumAmountInRange(SESSION_PERSON_ID, LocalDate.of(2026, 7, 5), LocalDate.of(2026, 7, 20))
        }
    }

    @Test
    fun `reading the active budget with no token is refused with a neutral 401 before the use case runs`() {
        val exception = rejectGetActive()

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals("UNAUTHENTICATED", item.code)
        verify(exactly = 0) { budgetRepository.findLiveBudgetCovering(any(), any()) }
    }

    @Test
    fun `reading the active budget with an unresolvable token is refused with a neutral 401`() {
        val exception = rejectGetActive("Bearer $DEAD_TOKEN")

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        verify(exactly = 0) { budgetRepository.findLiveBudgetCovering(any(), any()) }
    }

    @Test
    fun `an authenticated request with expenses outside any live budget returns 200 with the total`() {
        every { expenseRepository.sumAmount(SESSION_PERSON_ID) } returns 30_000
        every { budgetRepository.findAllLiveBudgets(SESSION_PERSON_ID) } returns emptyList()

        val response = client.toBlocking().exchange(
            getDefault("Bearer $LIVE_TOKEN"),
            Argument.of(DataResponse::class.java, DefaultBudgetResponse::class.java),
        )

        assertEquals(HttpStatus.OK, response.status)
        assertEquals(30_000, (response.body()!!.data as DefaultBudgetResponse).spentInCents)
    }

    @Test
    fun `all expenses covered by live budgets returns 200 with a zero spent amount`() {
        every { budgetRepository.findAllLiveBudgets(SESSION_PERSON_ID) } returns listOf(
            budget(id = "budget-1", personId = SESSION_PERSON_ID, startDate = LocalDate.of(2026, 7, 1), endDate = LocalDate.of(2026, 7, 31)),
        )
        every { expenseRepository.sumAmount(SESSION_PERSON_ID) } returns 30_000
        every { expenseRepository.sumAmountInRange(SESSION_PERSON_ID, LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 31)) } returns 30_000

        val response = client.toBlocking().exchange(
            getDefault("Bearer $LIVE_TOKEN"),
            Argument.of(DataResponse::class.java, DefaultBudgetResponse::class.java),
        )

        assertEquals(HttpStatus.OK, response.status)
        assertEquals(0, (response.body()!!.data as DefaultBudgetResponse).spentInCents)
    }

    @Test
    fun `no expenses registered returns 200 with a zero spent amount, never 404`() {
        val response = client.toBlocking().exchange(
            getDefault("Bearer $LIVE_TOKEN"),
            Argument.of(DataResponse::class.java, DefaultBudgetResponse::class.java),
        )

        assertEquals(HttpStatus.OK, response.status)
        assertEquals(0, (response.body()!!.data as DefaultBudgetResponse).spentInCents)
    }

    @Test
    fun `a removed budget's period no longer counts against the default spend`() {
        every { budgetRepository.findAllLiveBudgets(SESSION_PERSON_ID) } returns emptyList()
        every { expenseRepository.sumAmount(SESSION_PERSON_ID) } returns 30_000

        val response = client.toBlocking().exchange(
            getDefault("Bearer $LIVE_TOKEN"),
            Argument.of(DataResponse::class.java, DefaultBudgetResponse::class.java),
        )

        assertEquals(30_000, (response.body()!!.data as DefaultBudgetResponse).spentInCents)
    }

    @Test
    fun `another person's budgets and expenses never enter the calculation`() {
        every { expenseRepository.sumAmount(SESSION_PERSON_ID) } returns 10_000
        every { budgetRepository.findAllLiveBudgets(SESSION_PERSON_ID) } returns emptyList()

        val response = client.toBlocking().exchange(
            getDefault("Bearer $LIVE_TOKEN"),
            Argument.of(DataResponse::class.java, DefaultBudgetResponse::class.java),
        )

        verify(exactly = 0) { expenseRepository.sumAmount(match { it != SESSION_PERSON_ID }) }
        assertEquals(10_000, (response.body()!!.data as DefaultBudgetResponse).spentInCents)
        verify(exactly = 0) { budgetRepository.findAllLiveBudgets(match { it != SESSION_PERSON_ID }) }
    }

    @Test
    fun `reading the default budget with no token is refused with a neutral 401 before the use case runs`() {
        val exception = rejectGetDefault()

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals("UNAUTHENTICATED", item.code)
        verify(exactly = 0) { expenseRepository.sumAmount(any()) }
    }

    @Test
    fun `reading the default budget with an unresolvable token is refused with a neutral 401`() {
        val exception = rejectGetDefault("Bearer $DEAD_TOKEN")

        verify(exactly = 0) { expenseRepository.sumAmount(any()) }
        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
    }
}
