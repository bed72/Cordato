package com.bed.cordato

import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

@RunWith(Parameterized::class)
class WidgetMoneyTest(
    private val scenario: String,
    private val cents: Long,
    private val complete: String,
    private val number: String
) {
    @Test
    fun preservesCompleteCurrency() {
        assertEquals(complete, WidgetMoney.fromCents(cents).complete)
    }

    @Test
    fun preservesEveryNumericDigit() {
        assertEquals(number, WidgetMoney.fromCents(cents).number)
    }

    companion object {
        @JvmStatic
        @Parameterized.Parameters(name = "{0}")
        fun amounts(): List<Array<Any>> = listOf(
            arrayOf("zero", 0L, "R$ 0,00", "0,00"),
            arrayOf("one cent", 1L, "R$ 0,01", "0,01"),
            arrayOf("negative cent", -1L, "-R$ 0,01", "-0,01"),
            arrayOf("monthly total", 313732L, "R$ 3.137,32", "3.137,32"),
            arrayOf("below fifteen million", 1499999999L, "R$ 14.999.999,99", "14.999.999,99"),
            arrayOf("fifteen million", 1500000000L, "R$ 15.000.000,00", "15.000.000,00"),
            arrayOf("above fifteen million", 1500000001L, "R$ 15.000.000,01", "15.000.000,01"),
            arrayOf("negative millions", -1500000001L, "-R$ 15.000.000,01", "-15.000.000,01"),
            arrayOf("maximum signed cents", Long.MAX_VALUE, "R$ 92.233.720.368.547.758,07", "92.233.720.368.547.758,07"),
            arrayOf("minimum signed cents", Long.MIN_VALUE, "-R$ 92.233.720.368.547.758,08", "-92.233.720.368.547.758,08")
        )
    }
}
