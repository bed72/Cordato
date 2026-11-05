import SwiftUI
import UIKit

struct WidgetSummaryView: View {
    let entry: AddExpenseEntry
    let dimensions: WidgetDimensions
    let textMuted: Color
    @ScaledMetric(relativeTo: .headline) private var preferredFontSize = 22.0
    @ScaledMetric(relativeTo: .caption) private var preferredCaptionSize = 12.0

    private func amountLayout(for money: WidgetMoney) -> WidgetAmountLayout {
        let fontSize = min(
            preferredFontSize * dimensions.preferredAmountFont / 22,
            dimensions.maximumAmountFont
        )
        let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        let inlineWidth = (money.complete as NSString).size(withAttributes: [.font: font]).width
        let numberWidth = (money.number as NSString).size(withAttributes: [.font: font]).width

        return WidgetAmountLayout(
            money: money,
            availableWidth: max(1, dimensions.summaryWidth - 2),
            inlineWidth: inlineWidth,
            numberWidth: numberWidth,
            baseFontSize: fontSize
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Gastos de \(entry.month)")
                .font(.system(size: min(preferredCaptionSize, 14)))
                .foregroundStyle(textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let money = entry.money {
                let layout = amountLayout(for: money)

                VStack(alignment: .leading, spacing: 2) {
                    if layout.separateCurrency {
                        Text("R$")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(layout.text)
                        .font(.system(size: layout.fontSize, weight: .bold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true)
                }
            } else {
                Text("Abra para atualizar")
                    .font(.system(size: min(preferredCaptionSize * 13 / 12, 16)))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}
