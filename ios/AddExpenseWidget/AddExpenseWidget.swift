import SwiftUI
import WidgetKit

struct AddExpenseWidgetView: View {
    let entry: AddExpenseEntry
    @Environment(\.colorScheme) private var colorScheme

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

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.month)
                .font(.subheadline)
                .foregroundStyle(textMuted)
            Text(entry.amount ?? "Abra para atualizar")
                .font(entry.amount == nil ? .subheadline : .system(size: 16, weight: .semibold))
                .minimumScaleFactor(0.55)
                .lineLimit(entry.amount == nil ? 2 : 1)
            Spacer(minLength: 0)
            Text("+ Adicionar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.month), \(entry.amount ?? "Abra para atualizar"). Adicionar despesa no Cordato")
        .widgetURL(URL(string: "cordato://widget/add-expense?homeWidget=true"))
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
        .supportedFamilies([.systemSmall])
    }
}
