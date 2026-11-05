import SwiftUI
import WidgetKit

struct AddExpenseWidgetView: View {
    let entry: AddExpenseEntry
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var family

    private var background: Color {
        colorScheme == .dark
            ? Color(red: 15 / 255, green: 21 / 255, blue: 17 / 255)
            : Color(red: 246 / 255, green: 251 / 255, blue: 244 / 255)
    }

    private var accent: Color {
        colorScheme == .dark
            ? Color(red: 147 / 255, green: 213 / 255, blue: 169 / 255)
            : Color(red: 43 / 255, green: 106 / 255, blue: 70 / 255)
    }

    private var text: Color {
        colorScheme == .dark
            ? Color(red: 223 / 255, green: 228 / 255, blue: 221 / 255)
            : Color(red: 24 / 255, green: 29 / 255, blue: 25 / 255)
    }

    private var textMuted: Color {
        colorScheme == .dark
            ? Color(red: 192 / 255, green: 201 / 255, blue: 192 / 255)
            : Color(red: 65 / 255, green: 73 / 255, blue: 66 / 255)
    }

    private var textOnAccent: Color {
        colorScheme == .dark
            ? Color(red: 0, green: 33 / 255, blue: 16 / 255)
            : .white
    }

    private var content: some View {
        GeometryReader { geometry in
            let dimensions = WidgetDimensions(
                width: geometry.size.width,
                size: family == .systemMedium ? .medium : .small
            )

            Group {
                if dimensions.horizontal {
                    HStack(spacing: dimensions.summaryActionSpacing) {
                        summary(dimensions: dimensions)
                        action.frame(width: dimensions.actionWidth)
                    }
                } else {
                    VStack(alignment: .leading, spacing: dimensions.summaryActionSpacing) {
                        summary(dimensions: dimensions)
                        action
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .id(family)
        .foregroundStyle(text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.month), \(entry.money?.complete ?? "Abra para atualizar"). Adicionar despesa no Cordato")
        .widgetURL(URL(string: "cordato://widget/add-expense?homeWidget=true"))
    }

    private func summary(dimensions: WidgetDimensions) -> some View {
        WidgetSummaryView(entry: entry, dimensions: dimensions, textMuted: textMuted)
            .frame(width: dimensions.summaryWidth, alignment: .leading)
    }

    @ViewBuilder
    private var action: some View {
        if #available(iOSApplicationExtension 16.0, *) {
            WidgetRenderedActionView(background: accent, foreground: textOnAccent)
        } else {
            WidgetActionView(background: accent, foreground: textOnAccent, backgroundOpacity: 1)
        }
    }

    var body: some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(background, for: .widget)
        } else {
            content.padding(16).background(background)
        }
    }
}

@main
struct AddExpenseWidget: Widget {
    let kind = "AddExpenseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AddExpenseProvider()) { entry in
            AddExpenseWidgetView(entry: entry)
        }
        .configurationDisplayName("Adicionar despesa")
        .description("Abra o cadastro de uma nova despesa no Cordato.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
