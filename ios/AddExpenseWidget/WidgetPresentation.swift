import Foundation

struct WidgetMoney {
    let complete: String
    let number: String

    init(cents: Int64) {
        let whole = String(cents.magnitude / 100)
        var grouped = ""
        for (index, digit) in whole.reversed().enumerated() {
            if index > 0 && index.isMultiple(of: 3) {
                grouped.append(".")
            }
            grouped.append(digit)
        }

        let fraction = String(cents.magnitude % 100)
        let unsigned = String(grouped.reversed()) + "," + (fraction.count == 1 ? "0" : "") + fraction
        number = (cents < 0 ? "-" : "") + unsigned
        complete = (cents < 0 ? "-R$ " : "R$ ") + unsigned
    }
}

enum WidgetSize {
    case small
    case medium
}

struct WidgetDimensions {
    let width: Double
    let size: WidgetSize

    var horizontal: Bool { size == .medium }
    var actionWidth: Double { 136 }
    var summaryWidth: Double { max(1, width - (horizontal ? actionWidth + 12 : 0)) }
    var preferredAmountFont: Double { size == .small ? 17 : 20 }
    var maximumAmountFont: Double { size == .small ? 19 : 24 }
    var summaryActionSpacing: Double { size == .small ? 10 : 12 }
}

enum WidgetColorMode {
    case fullColor
    case accented
    case vibrant

    var actionBackgroundOpacity: Double { self == .fullColor ? 1 : 0.16 }
    var usesSystemForeground: Bool { self != .fullColor }
}

struct WidgetAmountLayout {
    let text: String
    let separateCurrency: Bool
    let fontSize: Double

    init(
        money: WidgetMoney,
        availableWidth: Double,
        inlineWidth: Double,
        numberWidth: Double,
        baseFontSize: Double
    ) {
        separateCurrency = inlineWidth > availableWidth
        let measuredWidth = separateCurrency ? numberWidth : inlineWidth
        let scale = min(1, max(1, availableWidth) / max(1, measuredWidth))
        text = separateCurrency ? money.number : money.complete
        fontSize = baseFontSize * scale
    }
}
