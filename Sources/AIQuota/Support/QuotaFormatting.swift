import Foundation

/// Formatação de números, moeda e datas para exibição em português do Brasil.
enum QuotaFormatting {
    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()

    static func tokens(_ value: Int) -> String {
        integerFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func cost(_ value: Double) -> String {
        "US$ " + String(format: "%.2f", value)
    }

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// Formata o tempo restante até `date`, a partir de `now`, como "3h56m" ou "42s".
    static func remaining(until date: Date, now: Date) -> String {
        let interval = max(0, date.timeIntervalSince(now))
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%dh%02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm%02ds", minutes, seconds)
        } else {
            return "\(seconds)s"
        }
    }
}
