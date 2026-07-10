package com.bed.cordato.core.domain

import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

import com.bed.cordato.core.domain.value_objects.MoneyValueObject

class MoneyTest {

    @Test
    fun `accepts a strictly positive amount in cents`() {
        val money = MoneyValueObject.of(1_234)

        assertNotNull(money)
        assertEquals(1_234, money.cents)
    }

    @Test
    fun `rejects a zero amount`() {
        assertNull(MoneyValueObject.of(0))
    }

    @Test
    fun `rejects a negative amount`() {
        assertNull(MoneyValueObject.of(-1))
    }
}
