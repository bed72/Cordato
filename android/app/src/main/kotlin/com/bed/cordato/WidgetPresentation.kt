package com.bed.cordato

import kotlin.math.min

import java.util.Locale
import java.math.BigDecimal
import java.text.NumberFormat

data class WidgetMoney(val complete: String, val number: String) {
    companion object {
        fun fromCents(cents: Long): WidgetMoney {
            val formatter = NumberFormat.getNumberInstance(Locale.forLanguageTag("pt-BR")).apply {
                minimumFractionDigits = 2
                maximumFractionDigits = 2
            }
            val number = formatter.format(BigDecimal.valueOf(cents, 2))
            val complete = if (cents < 0) "-R$ ${number.removePrefix("-")}" else "R$ $number"

            return WidgetMoney(complete, number)
        }
    }
}

data class WidgetDimensions(val width: Float, val height: Float) {
    val singleRow: Boolean = height < 96
    val horizontal: Boolean = singleRow || (width >= 300 && width > height)
    val tight: Boolean = height < 150
    val horizontalPadding: Float = 16f
    val verticalPadding: Float = when {
        singleRow -> 4f
        tight -> 8f
        else -> 16f
    }
    val actionHeight: Float = if (tight) 32f else 44f
    val compactAction: Boolean = singleRow && width < 300
    val actionWidth: Float = if (compactAction) actionHeight else 136f
    val summaryWidth: Float = (width - horizontalPadding * 2 - if (horizontal) actionWidth + 12 else 0f)
        .coerceAtLeast(1f)
    val canSplitCurrency: Boolean = !singleRow && (!tight || horizontal)
    val preferredAmountFont: Float = when {
        compactAction -> 15f
        singleRow -> 16f
        !horizontal -> 19f
        else -> 22f
    }
    val maximumAmountFont: Float = when {
        compactAction -> 15f
        singleRow -> 16f
        !horizontal -> 21f
        else -> 26f
    }
    val amountHeight: Float = when {
        singleRow -> 24f
        tight && !horizontal -> 28f
        else -> 32f
    }
}

data class WidgetAmountLayout(val text: String, val separateCurrency: Boolean, val fontSize: Float) {
    companion object {
        fun fit(
            money: WidgetMoney,
            availableWidth: Float,
            inlineWidth: Float,
            numberWidth: Float,
            baseFontSize: Float,
            canSplitCurrency: Boolean
        ): WidgetAmountLayout {
            val separateCurrency = canSplitCurrency && inlineWidth > availableWidth
            val measuredWidth = if (separateCurrency) numberWidth else inlineWidth
            val scale = min(1f, availableWidth.coerceAtLeast(1f) / measuredWidth.coerceAtLeast(1f))

            return WidgetAmountLayout(
                if (separateCurrency) money.number else money.complete,
                separateCurrency,
                baseFontSize * scale
            )
        }
    }
}
