import Foundation
import WidgetKit

struct AddExpenseEntry: TimelineEntry {
    let date: Date
    let month: String
    let money: WidgetMoney?
}

private struct MonthlySummary: Decodable {
    let month: String
    let cents: Int64
}

struct AddExpenseProvider: TimelineProvider {
    private let calendar = Calendar(identifier: .gregorian)
    private let brazilianLocale = Locale(identifier: "pt_BR")
    private let appGroup = "group.com.bed.cordato"
    private let summaryKey = "monthly_summary"

    func placeholder(in context: Context) -> AddExpenseEntry {
        entry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (AddExpenseEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AddExpenseEntry>) -> Void) {
        let now = Date()
        let currentEntry = entry(at: now)
        guard let nextMonth = calendar.dateInterval(of: .month, for: now)?.end else {
            completion(Timeline(entries: [currentEntry], policy: .never))
            return
        }

        let nextEntry = entry(at: nextMonth)
        completion(Timeline(entries: [currentEntry, nextEntry], policy: .atEnd))
    }

    private func entry(at date: Date) -> AddExpenseEntry {
        let month = monthTitle(for: date)
        let summary = readSummary(for: date)
        let money = summary.map { WidgetMoney(cents: $0.cents) }

        return AddExpenseEntry(date: date, month: month, money: money)
    }

    private func readSummary(for date: Date) -> MonthlySummary? {
        let preferences = UserDefaults(suiteName: appGroup)
        guard let stored = preferences?.string(forKey: summaryKey),
            let data = stored.data(using: .utf8),
            let summary = try? JSONDecoder().decode(MonthlySummary.self, from: data)
        else {
            return nil
        }

        guard summary.month == monthKey(for: date) else {
            return nil
        }

        return summary
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = brazilianLocale
        formatter.dateFormat = "MMMM"

        return formatter.string(from: date).capitalized(with: brazilianLocale)
    }

    private func monthKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"

        return formatter.string(from: date)
    }
}
