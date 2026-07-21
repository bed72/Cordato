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

import com.bed.cordato.features.budget.domain.entities.BudgetEntity
import com.bed.cordato.features.budget.domain.value_objects.NoteValueObject
import com.bed.cordato.features.budget.infrastructure.http.responses.BudgetResponse
import com.bed.cordato.features.budget.application.driven.repositories.BudgetRepository

private const val DEAD_TOKEN = "dead-token"

/**
 * End-to-end cover of `POST /budgets` through the edge guard (filter + binder), the edge Bean Validation,
 * the **real** `CreateBudgetUseCase`, and the neutral error contract. Only the [BudgetRepository] is a
 * double (wired globally by [com.bed.cordato.features.budget.factories.BudgetRepositoryMockFactory]), so the
 * whole route→use-case path runs; the fake session repository (wired globally) resolves only [LIVE_TOKEN] to
 * [SESSION_PERSON_ID]. `hasOverlappingLiveBudget` defaults to `false` so a plain valid request succeeds; the
 * `422 OVERLAPPING_BUDGET` path stubs it to `true`.
 */
@MicronautTest
class BudgetControllerTest {

    @Inject
    lateinit var repository: BudgetRepository

    @Inject
    @field:Client("/")
    lateinit var client: HttpClient

    @BeforeTest
    fun reset() {
        clearMocks(repository)
        every { repository.hasOverlappingLiveBudget(any(), any(), any()) } returns false
    }

    private fun post(body: Any, authorization: String? = null): HttpRequest<Any> {
        val request = HttpRequest.POST<Any>("/v1/budgets", body)
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun reject(body: Any, authorization: String? = null): HttpClientResponseException =
        try {
            client.toBlocking().exchange(post(body, authorization), String::class.java)
            error("Expected the request to be refused with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    @Test
    fun `an authenticated valid request creates the budget and returns 201`() {
        val persisted = slot<BudgetEntity>()
        every { repository.create(capture(persisted)) } just Runs

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
        verify(exactly = 1) { repository.create(any()) }
        assertEquals(100_000, body.amountInCents)
        assertEquals("Viagem", body.note)
        assertEquals(body.id, persisted.captured.id)
        assertEquals(SESSION_PERSON_ID, persisted.captured.personId)
        assertEquals(LocalDate.of(2026, 7, 1), body.startDate)
        assertEquals(LocalDate.of(2026, 7, 31), body.endDate)
    }

    @Test
    fun `an absent note creates a budget without one`() {
        val persisted = slot<BudgetEntity>()
        every { repository.create(capture(persisted)) } just Runs

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
        verify(exactly = 0) { repository.create(any()) }
        assertEquals(null, item.source)
        assertEquals("UNAUTHENTICATED", item.code)
    }

    @Test
    fun `an unresolvable token is refused with a neutral 401 before the use case runs`() {
        val exception = reject(mapOf("amount_in_cents" to 100_000), "Bearer $DEAD_TOKEN")

        verify(exactly = 0) { repository.create(any()) }
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
        verify(exactly = 0) { repository.create(any()) }
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
        verify(exactly = 0) { repository.create(any()) }
        assertTrue(errors.any { it.source?.field == "amountInCents" }, "$errors")
    }

    @Test
    fun `missing dates fail edge validation with 400 per field without persisting`() {
        val exception = reject(mapOf("amount_in_cents" to 100_000), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val errors = exception.response.getBody(ErrorsResponse::class.java).get().errors
        verify(exactly = 0) { repository.create(any()) }
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

        verify(exactly = 0) { repository.create(any()) }
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
        verify(exactly = 0) { repository.create(any()) }
        assertEquals(null, item.source)
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
        verify(exactly = 0) { repository.create(any()) }
        assertEquals(null, item.source)
        assertEquals("INVALID_PERIOD", item.code)
    }

    @Test
    fun `a period overlapping another live budget is rejected by the domain with a scalar 422 without persisting`() {
        every { repository.hasOverlappingLiveBudget(SESSION_PERSON_ID, any(), any()) } returns true

        val exception = reject(
            mapOf("amount_in_cents" to 100_000, "start_date" to "2026-07-01", "end_date" to "2026-07-15"),
            "Bearer $LIVE_TOKEN",
        )

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        verify(exactly = 0) { repository.create(any()) }
        assertEquals(null, item.source)
        assertEquals("OVERLAPPING_BUDGET", item.code)
    }

    @Test
    fun `adjacent intervals with no overlap are accepted and return 201`() {
        every { repository.create(any()) } just Runs

        val response = client.toBlocking().exchange(
            post(
                mapOf("amount_in_cents" to 100_000, "start_date" to "2026-07-16", "end_date" to "2026-07-31"),
                "Bearer $LIVE_TOKEN",
            ),
            Argument.of(DataResponse::class.java, BudgetResponse::class.java),
        )

        assertEquals(HttpStatus.CREATED, response.status)
        verify(exactly = 1) { repository.create(any()) }
    }
}
