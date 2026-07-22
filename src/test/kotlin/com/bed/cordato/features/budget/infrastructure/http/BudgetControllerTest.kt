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

import com.bed.cordato.features.budget.factories.budget

import com.bed.cordato.features.budget.domain.entities.BudgetEntity
import com.bed.cordato.features.budget.domain.value_objects.NoteValueObject
import com.bed.cordato.features.budget.infrastructure.http.responses.BudgetResponse
import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository
import com.bed.cordato.features.budget.infrastructure.http.responses.ActiveBudgetResponse

import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

private const val DEAD_TOKEN = "dead-token"

/**
 * End-to-end cover of `POST /budgets` and `GET /budgets/active` through the edge guard (filter + binder),
 * the edge Bean Validation, the **real** `CreateBudgetUseCase`/`GetActiveBudgetUseCase`, and the neutral
 * error contract. Only the [BudgetRepository] and expense's [ExpenseRepository] are doubles (wired globally
 * by [com.bed.cordato.features.budget.factories.BudgetRepositoryMockFactory] and
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
        every { budgetRepository.hasOverlappingLiveBudget(any(), any(), any()) } returns false
        every { expenseRepository.sumAmountInRange(any(), any(), any()) } returns 0
    }

    private fun post(body: Any, authorization: String? = null): HttpRequest<Any> {
        val request = HttpRequest.POST<Any>("/v1/budgets", body)
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun getActive(authorization: String? = null): HttpRequest<Any> {
        val request = HttpRequest.GET<Any>("/v1/budgets/active")
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun reject(body: Any, authorization: String? = null): HttpClientResponseException =
        try {
            client.toBlocking().exchange(post(body, authorization), String::class.java)
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

    @Test
    fun `an authenticated valid request creates the budget and returns 201`() {
        val persisted = slot<BudgetEntity>()
        every { budgetRepository.create(capture(persisted)) } just Runs

        val response = client.toBlocking().exchange(
            post(
                mapOf(
                    "amount_in_cents" to 100_000,
                    "start_date" to "2026-07-01",
                    "end_date" to "2026-07-31",
                    "note" to "  Viagem  ",
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
                "amount_in_cents" to 100_000,
                "start_date" to "2026-07-01",
                "end_date" to "2026-07-31",
                "note" to tooLong,
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
}
