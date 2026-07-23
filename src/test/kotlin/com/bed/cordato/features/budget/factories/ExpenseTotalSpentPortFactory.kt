package com.bed.cordato.features.budget.factories

import io.mockk.every
import io.mockk.mockk

import com.bed.cordato.features.budget.application.driven.ports.ExpenseTotalSpentPort

/** A [ExpenseTotalSpentPort] mock that always answers [amount], mirroring [expenseSpentAmountPortOf]. */
fun expenseTotalSpentPortOf(amount: Long): ExpenseTotalSpentPort {
    val port = mockk<ExpenseTotalSpentPort>()
    every { port(any()) } returns amount
    return port
}
