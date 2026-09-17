import Foundation

enum Formatting {
    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()

    static func tokens(_ value: Int) -> String {
        integerFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func cost(_ value: Double) -> String {
        "US$ " + String(format: "%.2f", value)
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.1f", value) + "%"
    }

    static func date(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func remaining(until date: Date, now: Date = Date()) -> String {
        let interval = max(0, date.timeIntervalSince(now))
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h\(String(format: "%02d", minutes))m"
    }

    static func padded(_ string: String, to length: Int) -> String {
        string.count >= length ? string : string + String(repeating: " ", count: length - string.count)
    }
}
