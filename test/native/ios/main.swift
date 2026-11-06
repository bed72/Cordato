import XCTest

final class WidgetPresentationTests: XCTestCase {
    func testZero() { assertMoney(0, "R$ 0,00", "0,00") }
    func testCent() { assertMoney(1, "R$ 0,01", "0,01") }
    func testNegativeCent() { assertMoney(-1, "-R$ 0,01", "-0,01") }
    func testMonthlyTotal() { assertMoney(313732, "R$ 3.137,32", "3.137,32") }
    func testBelowFifteenMillion() { assertMoney(1499999999, "R$ 14.999.999,99", "14.999.999,99") }
    func testFifteenMillion() { assertMoney(1500000000, "R$ 15.000.000,00", "15.000.000,00") }
    func testAboveFifteenMillion() { assertMoney(1500000001, "R$ 15.000.000,01", "15.000.000,01") }
    func testNegativeMillions() { assertMoney(-1500000001, "-R$ 15.000.000,01", "-15.000.000,01") }
    func testMaximumCents() { assertMoney(Int64.max, "R$ 92.233.720.368.547.758,07", "92.233.720.368.547.758,07") }
    func testMinimumCents() { assertMoney(Int64.min, "-R$ 92.233.720.368.547.758,08", "-92.233.720.368.547.758,08") }

    private func assertMoney(_ cents: Int64, _ complete: String, _ number: String, file: StaticString = #filePath, line: UInt = #line) {
        let money = WidgetMoney(cents: cents)

        XCTAssertEqual(money.complete, complete, file: file, line: line)
        XCTAssertEqual(money.number, number, file: file, line: line)
    }

    func testSmallComposition() {
        let dimensions = WidgetDimensions(width: 126, size: .small)

        XCTAssertFalse(dimensions.horizontal)
        XCTAssertEqual(dimensions.summaryWidth, 126)
        XCTAssertEqual(dimensions.actionWidth, 136)
    }

    func testMediumComposition() {
        let dimensions = WidgetDimensions(width: 300, size: .medium)

        XCTAssertTrue(dimensions.horizontal)
        XCTAssertEqual(dimensions.actionWidth, 136)
        XCTAssertEqual(dimensions.summaryWidth, 152)
    }

    func testSmallestMediumComposition() {
        let dimensions = WidgetDimensions(width: 240, size: .medium)

        XCTAssertTrue(dimensions.horizontal)
        XCTAssertEqual(dimensions.actionWidth, 136)
        XCTAssertEqual(dimensions.summaryWidth, 92)
    }

    func testSmallFamilyRemainsVerticalRegardlessOfMeasuredWidth() {
        XCTAssertFalse(WidgetDimensions(width: 300, size: .small).horizontal)
    }

    func testMediumFamilyRemainsHorizontalAtNarrowMeasuredWidth() {
        let dimensions = WidgetDimensions(width: 220, size: .medium)

        XCTAssertTrue(dimensions.horizontal)
        XCTAssertEqual(dimensions.summaryWidth, 72)
    }

    func testChangingFamiliesDoesNotDependOnPreviousGeometry() {
        XCTAssertFalse(WidgetDimensions(width: 126, size: .small).horizontal)
        XCTAssertTrue(WidgetDimensions(width: 126, size: .medium).horizontal)
        XCTAssertFalse(WidgetDimensions(width: 300, size: .small).horizontal)
    }

    func testSmallAmountUsesSmallerFont() {
        let dimensions = WidgetDimensions(width: 126, size: .small)

        XCTAssertEqual(dimensions.preferredAmountFont, 16)
        XCTAssertEqual(dimensions.maximumAmountFont, 18)
        XCTAssertEqual(dimensions.summaryActionSpacing, 10)
    }

    func testMediumAmountKeepsLargerFont() {
        let dimensions = WidgetDimensions(width: 300, size: .medium)

        XCTAssertEqual(dimensions.preferredAmountFont, 18)
        XCTAssertEqual(dimensions.maximumAmountFont, 22)
        XCTAssertEqual(dimensions.summaryActionSpacing, 12)
    }

    func testFullColorActionUsesOpaqueDesignSystemBackground() {
        XCTAssertEqual(WidgetColorMode.fullColor.actionBackgroundOpacity, 1)
        XCTAssertFalse(WidgetColorMode.fullColor.usesSystemForeground)
    }

    func testAccentedActionKeepsTranslucentBackgroundBehindOpaqueText() {
        XCTAssertEqual(WidgetColorMode.accented.actionBackgroundOpacity, 0.16)
        XCTAssertTrue(WidgetColorMode.accented.usesSystemForeground)
    }

    func testVibrantActionKeepsTranslucentBackgroundBehindOpaqueText() {
        XCTAssertEqual(WidgetColorMode.vibrant.actionBackgroundOpacity, 0.16)
        XCTAssertTrue(WidgetColorMode.vibrant.usesSystemForeground)
    }

    func testExactWidthKeepsCurrencyInline() {
        let money = WidgetMoney(cents: 1500000000)
        let layout = WidgetAmountLayout(money: money, availableWidth: 180, inlineWidth: 180, numberWidth: 145, baseFontSize: 22)

        XCTAssertFalse(layout.separateCurrency)
        XCTAssertEqual(layout.text, money.complete)
        XCTAssertEqual(layout.fontSize, 22)
    }

    func testOverflowSeparatesCurrency() {
        let money = WidgetMoney(cents: 1500000001)
        let layout = WidgetAmountLayout(money: money, availableWidth: 150, inlineWidth: 180, numberWidth: 145, baseFontSize: 22)

        XCTAssertTrue(layout.separateCurrency)
        XCTAssertEqual(layout.text, "15.000.000,01")
        XCTAssertEqual(layout.fontSize, 22)
    }

    func testExtremeAmountKeepsAllDigitsBelowOldFontMinimum() {
        let money = WidgetMoney(cents: Int64.max)
        let layout = WidgetAmountLayout(money: money, availableWidth: 100, inlineWidth: 310, numberWidth: 280, baseFontSize: 26)

        XCTAssertEqual(layout.text, money.number)
        XCTAssertEqual(layout.fontSize, 26 * 100 / 280, accuracy: 0.001)
        XCTAssertLessThan(layout.fontSize, 14.3)
    }

    func testSeparatedNegativeKeepsSign() {
        let money = WidgetMoney(cents: Int64.min)
        let layout = WidgetAmountLayout(money: money, availableWidth: 100, inlineWidth: 320, numberWidth: 290, baseFontSize: 22)

        XCTAssertEqual(layout.text, "-92.233.720.368.547.758,08")
        XCTAssertTrue(layout.separateCurrency)
    }

    func testEnlargedFontUsesMeasuredWidth() {
        let money = WidgetMoney(cents: 1500000000)
        let layout = WidgetAmountLayout(money: money, availableWidth: 150, inlineWidth: 220, numberWidth: 180, baseFontSize: 26)

        XCTAssertEqual(layout.fontSize, 26 * 150 / 180, accuracy: 0.001)
        XCTAssertLessThanOrEqual(layout.fontSize * 180 / 26, 150.001)
    }

    func testNarrowMediumKeepsExtremeAmountInsideSpaceBesideFullAction() {
        let dimensions = WidgetDimensions(width: 220, size: .medium)
        let money = WidgetMoney(cents: Int64.max)
        let availableWidth = dimensions.summaryWidth - 2
        let layout = WidgetAmountLayout(
            money: money,
            availableWidth: availableWidth,
            inlineWidth: 250,
            numberWidth: 220,
            baseFontSize: dimensions.preferredAmountFont
        )

        XCTAssertTrue(layout.separateCurrency)
        XCTAssertEqual(layout.text, "92.233.720.368.547.758,07")
        XCTAssertEqual(layout.fontSize, 18 * 70 / 220, accuracy: 0.001)
        XCTAssertLessThanOrEqual(layout.fontSize * 220 / 18, availableWidth + 0.001)
    }
}

let suite = WidgetPresentationTests.defaultTestSuite
suite.run()
guard let execution = suite.testRun, execution.executionCount > 0 else {
    exit(1)
}
exit(execution.hasSucceeded ? 0 : 1)
