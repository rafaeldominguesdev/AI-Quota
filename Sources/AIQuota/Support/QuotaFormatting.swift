import Foundation

/// Formatação de números, moeda, tokens e datas para exibição em português do Brasil.
enum QuotaFormatting {
    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()

    static func tokens(_ value: Int) -> String {
        integerFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Versão curta, para caber na coluna da direita das linhas de provedor: "57,3 M", "842 k".
    static func compactTokens(_ value: Int) -> String {
        let absolute = abs(value)
        if absolute >= 1_000_000_000 {
            return (decimalFormatter.string(from: NSNumber(value: Double(value) / 1_000_000_000)) ?? "0") + " G"
        }
        if absolute >= 1_000_000 {
            return (decimalFormatter.string(from: NSNumber(value: Double(value) / 1_000_000)) ?? "0") + " M"
        }
        if absolute >= 1_000 {
            return (decimalFormatter.string(from: NSNumber(value: Double(value) / 1_000)) ?? "0") + " k"
        }
        return String(value)
    }

    static func cost(_ value: Double) -> String {
        "US$ " + String(format: "%.2f", value)
    }

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    /// "17:36"
    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// "17:36:04" — o relógio "ao vivo" do cabeçalho.
    static func clock(_ date: Date) -> String {
        clockFormatter.string(from: date)
    }

    /// "13" — rótulo de hora dos segmentos da timeline.
    static func hourLabel(_ date: Date) -> String {
        hourFormatter.string(from: date)
    }

    /// Contagem regressiva de largura fixa, "02:51:44", para o bloco principal.
    static func countdown(until date: Date, now: Date) -> String {
        let totalSeconds = Int(max(0, date.timeIntervalSince(now)))
        return String(
            format: "%02d:%02d:%02d",
            totalSeconds / 3600,
            (totalSeconds % 3600) / 60,
            totalSeconds % 60
        )
    }

    /// Forma compacta do tempo restante, "2h50m" ou "42s", para as linhas de provedor.
    static func remaining(until date: Date, now: Date) -> String {
        let totalSeconds = Int(max(0, date.timeIntervalSince(now)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 { return String(format: "%dh%02dm", hours, minutes) }
        if minutes > 0 { return String(format: "%dm%02ds", minutes, seconds) }
        return "\(seconds)s"
    }
}
