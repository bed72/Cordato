package com.bed.cordato.features.identity.domain

import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

class EmailTest {

    @Test
    fun `accepts a well-formed address and normalizes it`() {
        val email = EmailValueObject.of("  Alice@Example.COM ")

        assertNotNull(email)
        assertEquals("alice@example.com", email.value)
    }

    @Test
    fun `rejects addresses with an invalid format`() {
        assertNull(EmailValueObject.of(""))
        assertNull(EmailValueObject.of("alice"))
        assertNull(EmailValueObject.of("alice@example"))
        assertNull(EmailValueObject.of("alice@@example.com"))
        assertNull(EmailValueObject.of("ali ce@example.com"))
    }
}
