package com.bed.cordato.core.infrastructure.http.authentication.binders

import io.mockk.mockk

import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.assertFalse
import kotlin.test.assertEquals

import io.micronaut.http.HttpRequest
import io.micronaut.core.convert.ArgumentConversionContext

import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor

class AuthenticatedActorBinderTest {

    private val binder = AuthenticatedActorBinder()
    private val context = mockk<ArgumentConversionContext<AuthenticatedActor>>(relaxed = true)

    @Test
    fun `reads the person id the filter stashed and binds it as the typed actor`() {
        val request = HttpRequest.GET<Any>("/").setAttribute(AuthenticatedActor.ATTRIBUTE, "person-1")

        val result = binder.bind(context, request)

        assertTrue(result.isPresentAndSatisfied)
        assertEquals(AuthenticatedActor("person-1"), result.get())
    }

    @Test
    fun `an absent attribute is an unsatisfied binding, never a fabricated actor`() {
        val request = HttpRequest.GET<Any>("/")

        val result = binder.bind(context, request)

        assertFalse(result.isPresentAndSatisfied)
        assertFalse(result.value.isPresent)
    }
}
