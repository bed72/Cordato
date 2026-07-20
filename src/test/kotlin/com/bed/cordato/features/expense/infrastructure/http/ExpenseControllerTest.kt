package com.bed.cordato.features.expense.infrastructure.http

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
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

import io.micronaut.http.MediaType
import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpRequest
import io.micronaut.http.HttpResponse
import io.micronaut.core.type.Argument
import io.micronaut.http.client.HttpClient
import io.micronaut.http.client.annotation.Client
import io.micronaut.test.extensions.junit5.annotation.MicronautTest
import io.micronaut.http.client.exceptions.HttpClientResponseException

import com.bed.cordato.core.factories.LIVE_TOKEN
import com.bed.cordato.core.factories.SESSION_PERSON_ID
import com.bed.cordato.core.infrastructure.http.responses.DataResponse
import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse

import com.bed.cordato.features.expense.factories.expense
import com.bed.cordato.features.expense.domain.entities.ExpenseEntity
import com.bed.cordato.features.expense.domain.value_objects.DescriptionValueObject
import com.bed.cordato.features.expense.domain.value_objects.ExpenseCursorValueObject
import com.bed.cordato.features.expense.infrastructure.http.responses.ExpenseResponse
import com.bed.cordato.features.expense.infrastructure.http.mappers.responses.toToken
import com.bed.cordato.features.expense.application.driven.repositories.ExpenseRepository

private const val DEAD_TOKEN = "dead-token"

/**
 * End-to-end cover of `POST /expenses` through the edge guard (filter + binder), the edge Bean Validation,
 * the **real** `CreateExpenseUseCase`, and the neutral error contract. Only the [ExpenseRepository] is a
 * double (wired globally by [com.bed.cordato.features.expense.factories.ExpenseRepositoryMockFactory]), so the
 * whole route→use-case path runs; the fake session repository (wired globally) resolves only [LIVE_TOKEN] to
 * [SESSION_PERSON_ID]. The `422` domain path is reached through a **future date**, the one domain rule the
 * edge deliberately does not mirror (a non-positive amount is already refused by `@Positive` at the edge).
 */
@MicronautTest
class ExpenseControllerTest {

    @Inject
    lateinit var repository: ExpenseRepository

    @Inject
    @field:Client("/")
    lateinit var client: HttpClient

    @BeforeTest
    fun reset() = clearMocks(repository)

    private fun post(body: Any, authorization: String? = null): HttpRequest<Any> {
        val request = HttpRequest.POST<Any>("/v1/expenses", body)
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun get(authorization: String? = null, limit: Int? = null, cursor: String? = null): HttpRequest<Any> {
        val query = listOfNotNull(limit?.let { "limit=$it" }, cursor?.let { "cursor=$it" }).joinToString("&")
        val path = if (query.isEmpty()) "/v1/expenses" else "/v1/expenses?$query"
        val request = HttpRequest.GET<Any>(path)
        return if (authorization == null) request else request.header("Authorization", authorization)
    }

    private fun listPage(authorization: String? = null, limit: Int? = null, cursor: String? = null) =
        client.toBlocking().exchange(get(authorization, limit, cursor), Argument.of(DataResponse::class.java))

    private fun items(response: HttpResponse<DataResponse<*>>): List<Map<*, *>> =
        (response.body()!!.data as List<*>).map { it as Map<*, *> }

    private fun rejectGet(
        authorization: String? = null,
        limit: Int? = null,
        cursor: String? = null,
    ): HttpClientResponseException =
        try {
            client.toBlocking().exchange(get(authorization, limit, cursor), String::class.java)
            error("Expected the request to be refused with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    private fun reject(body: Any, authorization: String? = null): HttpClientResponseException =
        try {
            client.toBlocking().exchange(post(body, authorization), String::class.java)
            error("Expected the request to be refused with an HTTP error response")
        } catch (exception: HttpClientResponseException) {
            exception
        }

    @Test
    fun `an authenticated valid request registers the expense and returns 201`() {
        val persisted = slot<ExpenseEntity>()
        every { repository.create(capture(persisted)) } just Runs

        val response = client.toBlocking().exchange(
            post(
                mapOf("amount_in_cents" to 1_500, "date" to "2020-01-15", "description" to "  Almoço  "),
                "Bearer $LIVE_TOKEN",
            ),
            Argument.of(DataResponse::class.java, ExpenseResponse::class.java),
        )

        assertEquals(HttpStatus.CREATED, response.status)
        val body = response.body()!!.data as ExpenseResponse
        verify(exactly = 1) { repository.create(any()) }
        assertEquals(1_500, body.amountInCents)
        assertEquals("Almoço", body.description)
        assertEquals(body.id, persisted.captured.id)
        assertEquals(SESSION_PERSON_ID, persisted.captured.personId)
        assertEquals(LocalDate.of(2020, 1, 15), body.date)
    }

    @Test
    fun `an absent description registers an expense without one`() {
        val persisted = slot<ExpenseEntity>()
        every { repository.create(capture(persisted)) } just Runs

        val response = client.toBlocking().exchange(
            post(mapOf("amount_in_cents" to 900, "date" to "2020-01-15"), "Bearer $LIVE_TOKEN"),
            Argument.of(DataResponse::class.java, ExpenseResponse::class.java),
        )

        assertEquals(HttpStatus.CREATED, response.status)
        assertEquals(null, (response.body()!!.data as ExpenseResponse).description)
    }

    @Test
    fun `no token is refused with a neutral 401 before the use case runs`() {
        val exception = reject(mapOf("amount_in_cents" to 1_500, "date" to "2020-01-15"))

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        verify(exactly = 0) { repository.create(any()) }
        assertEquals(null, item.source)
        assertEquals("UNAUTHENTICATED", item.code)
    }

    @Test
    fun `an unresolvable token is refused with a neutral 401 before the use case runs`() {
        val exception = reject(mapOf("amount_in_cents" to 1_500), "Bearer $DEAD_TOKEN")

        verify(exactly = 0) { repository.create(any()) }
        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        assertEquals("UNAUTHENTICATED", exception.response.getBody(ErrorsResponse::class.java).get().errors.single().code)
    }

    @Test
    fun `a missing amount fails edge validation with 400 per field without persisting`() {
        val exception = reject(mapOf("date" to "2020-01-15"), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val errors = exception.response.getBody(ErrorsResponse::class.java).get().errors
        verify(exactly = 0) { repository.create(any()) }
        assertTrue(errors.all { it.code == "INVALID_REQUEST" })
        assertTrue(errors.any { it.source?.field == "amountInCents" }, "$errors")
    }

    @Test
    fun `a non-positive amount fails edge validation with 400 per field without persisting`() {
        val exception = reject(mapOf("amount_in_cents" to 0), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val errors = exception.response.getBody(ErrorsResponse::class.java).get().errors
        verify(exactly = 0) { repository.create(any()) }
        assertTrue(errors.all { it.code == "INVALID_REQUEST" })
        assertTrue(errors.any { it.source?.field == "amountInCents" }, "$errors")
    }

    @Test
    fun `an over-length description fails edge validation with 400 without persisting`() {
        val tooLong = "a".repeat(DescriptionValueObject.MAX_LENGTH + 1)

        val exception = reject(
            mapOf("amount_in_cents" to 1_500, "description" to tooLong),
            "Bearer $LIVE_TOKEN",
        )

        verify(exactly = 0) { repository.create(any()) }
        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        assertEquals("INVALID_REQUEST", exception.response.getBody(ErrorsResponse::class.java).get().errors.single().code)
    }

    @Test
    fun `a malformed body is rejected with a scalar 400 without persisting`() {
        val request = HttpRequest.POST("/v1/expenses", "not-json")
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
    fun `multiple invalid fields in POST expenses are each reported in errors`() {
        val tooLong = "a".repeat(DescriptionValueObject.MAX_LENGTH + 1)

        val exception = reject(mapOf("amount_in_cents" to 0, "description" to tooLong), "Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val errors = exception.response.getBody(ErrorsResponse::class.java).get().errors
        verify(exactly = 0) { repository.create(any()) }
        assertTrue(errors.all { it.code == "INVALID_REQUEST" })
        assertEquals(setOf("amountInCents", "description"), errors.mapNotNull { it.source?.field }.toSet())
    }

    @Test
    fun `a future date is rejected by the domain with a scalar 422 without persisting`() {
        val exception = reject(
            mapOf("amount_in_cents" to 1_500, "date" to "2999-01-01"),
            "Bearer $LIVE_TOKEN",
        )

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        verify(exactly = 0) { repository.create(any()) }
        assertEquals(null, item.source)
        assertEquals("FUTURE_DATE", item.code)
    }

    @Test
    fun `an authenticated list returns 200 with the actor's expenses in the envelope`() {
        every { repository.findByPerson(SESSION_PERSON_ID, null, 21) } returns listOf(
            expense(id = "e-1", personId = SESSION_PERSON_ID, amountInCents = 1_500, description = "Café"),
            expense(id = "e-2", personId = SESSION_PERSON_ID, amountInCents = 900, description = null),
        )

        val response = listPage("Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.OK, response.status)
        val body = response.body()!!
        // The owner listed is the authenticated actor, never a parameter/body; the default limit is 20,
        // so the repository is asked for 21 (limit + 1) to probe for a next page.
        verify(exactly = 1) { repository.findByPerson(SESSION_PERSON_ID, null, 21) }
        val page = items(response)
        assertNull(body.meta)
        assertNotNull(body.links)
        assertNull(body.links.next)
        assertEquals(listOf("e-1", "e-2"), page.map { it["id"] })
        assertEquals(listOf("Café", null), page.map { it["description"] })
        assertEquals(listOf(1_500, 900), page.map { it["amount_in_cents"] })
        assertTrue(body.links.self.endsWith("/v1/expenses"), body.links.self)
    }

    @Test
    fun `a page with more items than the limit is cut down and offers a next_cursor`() {
        val first = expense(id = "e-1", personId = SESSION_PERSON_ID, date = LocalDate.of(2026, 7, 10))
        val second = expense(id = "e-2", personId = SESSION_PERSON_ID, date = LocalDate.of(2026, 7, 9))
        val third = expense(id = "e-3", personId = SESSION_PERSON_ID, date = LocalDate.of(2026, 7, 8))
        every { repository.findByPerson(SESSION_PERSON_ID, null, 3) } returns listOf(first, second, third)

        val response = listPage("Bearer $LIVE_TOKEN", limit = 2)

        val body = response.body()!!
        assertEquals(listOf("e-1", "e-2"), items(response).map { it["id"] })
        assertNotNull(body.meta?.pagination?.nextCursor)
        assertNotNull(body.links?.next)
    }

    @Test
    fun `following the next_cursor decodes it and asks the repository for the next slice, landing on the last page`() {
        val after = ExpenseCursorValueObject.of(LocalDate.of(2026, 7, 9), "e-2")
        every { repository.findByPerson(SESSION_PERSON_ID, after, 21) } returns listOf(
            expense(id = "e-3", personId = SESSION_PERSON_ID, date = LocalDate.of(2026, 7, 8)),
        )

        val response = listPage("Bearer $LIVE_TOKEN", cursor = after.toToken())

        val body = response.body()!!
        assertEquals(listOf("e-3"), items(response).map { it["id"] })
        assertNull(body.meta)
        assertNull(body.links?.next)
        verify(exactly = 1) { repository.findByPerson(SESSION_PERSON_ID, after, 21) }
    }

    @Test
    fun `an authenticated actor with no expenses gets 200 with an empty data array and no next link`() {
        every { repository.findByPerson(SESSION_PERSON_ID, null, 21) } returns emptyList()

        val response = listPage("Bearer $LIVE_TOKEN")

        assertEquals(HttpStatus.OK, response.status)
        val body = response.body()!!
        assertTrue(items(response).isEmpty())
        assertNull(body.meta)
        assertNull(body.links?.next)
    }

    @Test
    fun `a limit above the ceiling is rejected with 400 without reaching the repository`() {
        val exception = rejectGet("Bearer $LIVE_TOKEN", limit = 101)

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        verify(exactly = 0) { repository.findByPerson(any(), any(), any()) }
    }

    @Test
    fun `a malformed cursor is rejected with a scalar 400 MALFORMED_REQUEST`() {
        val exception = rejectGet("Bearer $LIVE_TOKEN", cursor = "not-a-valid-cursor!!")

        assertEquals(HttpStatus.BAD_REQUEST, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals("MALFORMED_REQUEST", item.code)
        assertEquals(null, item.source)
        verify(exactly = 0) { repository.findByPerson(any(), any(), any()) }
    }

    @Test
    fun `listing with no token is refused with a neutral 401 before the use case runs`() {
        val exception = rejectGet()

        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        val item = exception.response.getBody(ErrorsResponse::class.java).get().errors.single()
        assertEquals("UNAUTHENTICATED", item.code)
        assertEquals(null, item.source)
        verify(exactly = 0) { repository.findByPerson(any(), any(), any()) }
    }

    @Test
    fun `listing with an unresolvable token is refused with a neutral 401 before the use case runs`() {
        val exception = rejectGet("Bearer $DEAD_TOKEN")

        verify(exactly = 0) { repository.findByPerson(any(), any(), any()) }
        assertEquals(HttpStatus.UNAUTHORIZED, exception.status)
        assertEquals("UNAUTHENTICATED", exception.response.getBody(ErrorsResponse::class.java).get().errors.single().code)
    }
}
