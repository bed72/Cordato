package com.bed.cordato.features.identity.domain

import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

import com.bed.cordato.features.identity.domain.value_objects.PasswordValueObject

class PasswordTest {

    @Test
    fun `accepts a password meeting the minimum length`() {
        val password = PasswordValueObject.of("a".repeat(PasswordValueObject.MIN_LENGTH))

        assertNotNull(password)
    }

    @Test
    fun `rejects a password shorter than the minimum`() {
        assertNull(PasswordValueObject.of("a".repeat(PasswordValueObject.MIN_LENGTH - 1)))
    }

    @Test
    fun `does not trim the password`() {
        val withSpaces = "   ${"x".repeat(PasswordValueObject.MIN_LENGTH)}   "
        val password = PasswordValueObject.of(withSpaces)

        assertNotNull(password)
        assertEquals(withSpaces, password.value)
    }
}
