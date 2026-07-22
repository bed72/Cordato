package com.bed.cordato.features.budget.factories

import io.mockk.every
import io.mockk.mockk

import com.bed.cordato.features.budget.application.driven.ports.ExpenseSpentAmountPort

/** A [ExpenseSpentAmountPort] mock that always answers [amount], mirroring core's `clockFixedAt`. */
fun expenseSpentAmountPortOf(amount: Long): ExpenseSpentAmountPort {
    val port = mockk<ExpenseSpentAmountPort>()
    every { port(any(), any(), any()) } returns amount
    return port
}
