import SwiftUI
import WidgetKit

struct AddExpenseEntry: TimelineEntry {
    let date: Date
}

struct AddExpenseProvider: TimelineProvider {
    func placeholder(in context: Context) -> AddExpenseEntry {
        AddExpenseEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (AddExpenseEntry) -> Void) {
        completion(AddExpenseEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AddExpenseEntry>) -> Void) {
        completion(Timeline(entries: [AddExpenseEntry(date: Date())], policy: .never))
    }
}

struct AddExpenseWidgetView: View {
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
            Text("Cordato")
                .font(.caption)
                .foregroundStyle(textMuted)
            Spacer(minLength: 0)
            Image(systemName: "plus")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            Text("Adicionar despesa")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Adicionar despesa no Cordato")
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
        StaticConfiguration(kind: kind, provider: AddExpenseProvider()) { _ in
            AddExpenseWidgetView()
        }
        .configurationDisplayName("Adicionar despesa")
        .description("Abra o cadastro de uma nova despesa no Cordato.")
        .supportedFamilies([.systemSmall])
    }
}
