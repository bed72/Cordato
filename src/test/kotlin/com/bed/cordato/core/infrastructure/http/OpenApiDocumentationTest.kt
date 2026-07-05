package com.bed.cordato.core.infrastructure.http

import io.micronaut.http.HttpStatus
import io.micronaut.http.client.HttpClient
import io.micronaut.http.client.annotation.Client
import io.micronaut.test.extensions.junit5.annotation.MicronautTest

import jakarta.inject.Inject

import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.assertEquals

/**
 * Verifies the compile-time OpenAPI artefacts are actually served at runtime: the generated document
 * and the Swagger UI that renders it, both exposed through the static-resource mappings in
 * application.properties. Boots the full app behind Netty; the swagger routes are static resources that
 * never reach the (globally mocked, see PersonControllerTest's SignUpUseCaseMockFactory) use case, so no
 * database is needed.
 */
@MicronautTest
class OpenApiDocumentationTest {

    @Inject
    @field:Client("/")
    lateinit var client: HttpClient

    @Test
    fun `serves the generated OpenAPI document with the sign-up route`() {
        val response = client.toBlocking().exchange("/swagger/cordato-api-1.0.yml", String::class.java)

        assertEquals(HttpStatus.OK, response.status)
        val body = response.body()!!
        assertTrue(body.contains("openapi:"), body)
        assertTrue(body.contains("Cordato API"), body)
        assertTrue(body.contains("/sign-up"), body)
        // The operation documented on PersonControllerDoc reaches the generated document.
        assertTrue(body.contains("operationId: signUp"), body)
    }

    @Test
    fun `serves the Swagger UI pointing at the generated document`() {
        val response = client.toBlocking().exchange("/swagger-ui/index.html", String::class.java)

        assertEquals(HttpStatus.OK, response.status)
        assertTrue(response.body()!!.contains("/swagger/cordato-api-1.0.yml"), "UI must reference the spec")
    }
}
