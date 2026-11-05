package com.bed.cordato

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetPresentationTest {
    @Test
    fun squareKeepsVerticalComposition() {
        val dimensions = WidgetDimensions(180f, 180f)

        assertFalse(dimensions.horizontal)
        assertFalse(dimensions.tight)
        assertEquals(148f, dimensions.summaryWidth, 0.001f)
        assertEquals(19f, dimensions.preferredAmountFont, 0.001f)
        assertEquals(21f, dimensions.maximumAmountFont, 0.001f)
    }

    @Test
    fun tallKeepsVerticalComposition() {
        assertFalse(WidgetDimensions(300f, 320f).horizontal)
    }

    @Test
    fun widthBelowBoundaryKeepsVerticalComposition() {
        assertFalse(WidgetDimensions(299f, 150f).horizontal)
    }

    @Test
    fun wideReservesActualButtonWidthAndSpacing() {
        val dimensions = WidgetDimensions(300f, 150f)

        assertTrue(dimensions.horizontal)
        assertEquals(120f, dimensions.summaryWidth, 0.001f)
        assertEquals(22f, dimensions.preferredAmountFont, 0.001f)
        assertEquals(26f, dimensions.maximumAmountFont, 0.001f)
    }

    @Test
    fun shortWideKeepsHorizontalCompositionAndCurrencySplit() {
        val dimensions = WidgetDimensions(300f, 96f)

        assertTrue(dimensions.horizontal)
        assertTrue(dimensions.tight)
        assertTrue(dimensions.canSplitCurrency)
        assertEquals(120f, dimensions.summaryWidth, 0.001f)
        assertEquals(32f, dimensions.actionHeight, 0.001f)
    }

    @Test
    fun shortNarrowKeepsCurrencyInlineToFitHeight() {
        val dimensions = WidgetDimensions(150f, 96f)

        assertFalse(dimensions.horizontal)
        assertTrue(dimensions.tight)
        assertFalse(dimensions.canSplitCurrency)
        assertEquals(118f, dimensions.summaryWidth, 0.001f)
        assertEquals(19f, dimensions.preferredAmountFont, 0.001f)
        assertEquals(21f, dimensions.maximumAmountFont, 0.001f)
        assertEquals(28f, dimensions.amountHeight, 0.001f)
    }

    @Test
    fun regularHeightBoundaryKeepsNormalPadding() {
        val dimensions = WidgetDimensions(150f, 150f)

        assertFalse(dimensions.tight)
        assertEquals(16f, dimensions.horizontalPadding, 0.001f)
        assertEquals(16f, dimensions.verticalPadding, 0.001f)
        assertEquals(44f, dimensions.actionHeight, 0.001f)
        assertEquals(19f, dimensions.preferredAmountFont, 0.001f)
        assertEquals(21f, dimensions.maximumAmountFont, 0.001f)
        assertEquals(32f, dimensions.amountHeight, 0.001f)
    }

    @Test
    fun singleRowWideKeepsFullActionAndInlineMoney() {
        val dimensions = WidgetDimensions(300f, 56f)

        assertTrue(dimensions.horizontal)
        assertTrue(dimensions.singleRow)
        assertFalse(dimensions.iconAction)
        assertFalse(dimensions.canSplitCurrency)
        assertEquals(120f, dimensions.summaryWidth, 0.001f)
        assertEquals(16f, dimensions.preferredAmountFont, 0.001f)
        assertEquals(16f, dimensions.maximumAmountFont, 0.001f)
        assertEquals(24f, dimensions.amountHeight, 0.001f)
    }

    @Test
    fun singleRowNarrowReservesCompactActionWithoutHidingMoney() {
        val dimensions = WidgetDimensions(150f, 56f)

        assertTrue(dimensions.horizontal)
        assertTrue(dimensions.iconAction)
        assertFalse(dimensions.canSplitCurrency)
        assertEquals(15f, dimensions.preferredAmountFont, 0.001f)
        assertEquals(15f, dimensions.maximumAmountFont, 0.001f)
        assertEquals(44f, dimensions.actionWidth, 0.001f)
        assertEquals(62f, dimensions.summaryWidth, 0.001f)
        assertEquals(16f, dimensions.horizontalPadding, 0.001f)
        assertEquals(4f, dimensions.verticalPadding, 0.001f)
        assertTrue(16f + dimensions.amountHeight + dimensions.verticalPadding * 2 <= dimensions.height)
    }

    @Test
    fun narrowMonthlyAmountShrinksInsideHorizontalInsets() {
        val dimensions = WidgetDimensions(190f, 80f)
        val money = WidgetMoney.fromCents(313732L)
        val layout = WidgetAmountLayout.fit(
            money,
            dimensions.summaryWidth - 2,
            110f,
            90f,
            dimensions.preferredAmountFont,
            dimensions.canSplitCurrency
        )

        assertEquals(102f, dimensions.summaryWidth, 0.001f)
        assertEquals(money.complete, layout.text)
        assertFalse(layout.separateCurrency)
        assertEquals(15f * 100f / 110f, layout.fontSize, 0.001f)
        assertTrue(layout.fontSize < 15f)
    }

    @Test
    fun exactWidthKeepsCompleteAmountInline() {
        val money = WidgetMoney.fromCents(1500000000L)
        val layout = WidgetAmountLayout.fit(money, 180f, 180f, 145f, 22f, true)

        assertFalse(layout.separateCurrency)
        assertEquals(money.complete, layout.text)
        assertEquals(22f, layout.fontSize, 0.001f)
    }

    @Test
    fun overflowMovesCurrencyWithoutRemovingDigits() {
        val money = WidgetMoney.fromCents(1500000001L)
        val layout = WidgetAmountLayout.fit(money, 150f, 180f, 145f, 22f, true)

        assertTrue(layout.separateCurrency)
        assertEquals("15.000.000,01", layout.text)
        assertEquals(22f, layout.fontSize, 0.001f)
    }

    @Test
    fun extremeAmountScalesBelowPreviousMinimumWithoutTruncation() {
        val money = WidgetMoney.fromCents(Long.MAX_VALUE)
        val layout = WidgetAmountLayout.fit(money, 100f, 310f, 280f, 26f, true)

        assertTrue(layout.separateCurrency)
        assertEquals(money.number, layout.text)
        assertEquals(26f * 100f / 280f, layout.fontSize, 0.001f)
        assertTrue(layout.fontSize < 12f)
    }

    @Test
    fun shortAmountScalesInlineWithoutLosingCurrency() {
        val money = WidgetMoney.fromCents(Long.MIN_VALUE)
        val layout = WidgetAmountLayout.fit(money, 134f, 310f, 280f, 22f, false)

        assertFalse(layout.separateCurrency)
        assertEquals(money.complete, layout.text)
        assertEquals(22f * 134f / 310f, layout.fontSize, 0.001f)
    }

    @Test
    fun separatedNegativeAmountRetainsSign() {
        val money = WidgetMoney.fromCents(-1500000001L)
        val layout = WidgetAmountLayout.fit(money, 150f, 190f, 155f, 22f, true)

        assertEquals("-15.000.000,01", layout.text)
        assertTrue(layout.separateCurrency)
    }

    @Test
    fun enlargedFontIsMeasuredBeforeScaling() {
        val money = WidgetMoney.fromCents(1500000000L)
        val layout = WidgetAmountLayout.fit(money, 150f, 220f, 180f, 26f, true)

        assertEquals(26f * 150f / 180f, layout.fontSize, 0.001f)
        assertTrue(layout.fontSize * 180f / 26f <= 150.001f)
    }
}
