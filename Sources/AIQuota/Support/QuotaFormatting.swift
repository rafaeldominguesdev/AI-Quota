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

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func cost(_ value: Double) -> String {
        "US$ " + (currencyFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value))
    }

    /// Mascara um e-mail para exibição: "fulano@gmail.com" → "f•••@g•••.com" — só a primeira
    /// letra de cada lado (usuário e domínio) fica visível.
    static func maskedEmail(_ email: String) -> String {
        let parts = email.split(separator: "@", maxSplits: 1)
        guard parts.count == 2, let localFirst = parts[0].first else { return email }
        let domain = parts[1]
        let domainParts = domain.split(separator: ".", maxSplits: 1)
        guard let domainFirst = domainParts.first?.first else {
            return "\(localFirst)•••@\(domain)"
        }
        let rest = domainParts.count > 1 ? ".\(domainParts[1])" : ""
        return "\(localFirst)•••@\(domainFirst)•••\(rest)"
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

    /// Quanto tempo FAZ desde um momento — o "Última leitura: agora" do rodapé da janela de
    /// Ajustes. Abaixo de meio minuto é "agora": o refresh roda a cada 30s, então contar segundos
    /// ali só faria o texto piscar sem informar nada.
    static func elapsed(since date: Date, now: Date) -> String {
        let seconds = Int(max(0, now.timeIntervalSince(date)))
        if seconds < 30 { return "agora" }
        if seconds < 3600 { return "há \(seconds / 60)min" }
        let hours = seconds / 3600
        if hours < 24 { return "há \(hours)h" }
        return "há \(hours / 24)d"
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

    /// Versão compacta de uma unidade só, para caber ao lado da barrinha na barra de menu:
    /// "2d", "4h", "6m" — sem o prefixo "em" e sem a segunda unidade. "0m" quando já resetou,
    /// para nunca ficar em branco ali (não há espaço para "resetou" por extenso).
    static func resetInCompact(until date: Date, now: Date = Date()) -> String {
        let totalSeconds = date.timeIntervalSince(now)
        guard totalSeconds > 0 else { return "0m" }

        let totalMinutes = Int(totalSeconds / 60)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 { return "\(days)d" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }

    /// Contagem regressiva de uma janela de cota, no formato do painel de referência:
    /// "em 4d10h", "em 21h27m", "em 6m" — e "resetou" quando a data já passou.
    static func resetIn(until date: Date, now: Date = Date()) -> String {
        let totalSeconds = date.timeIntervalSince(now)
        guard totalSeconds > 0 else { return "resetou" }

        let totalMinutes = Int(totalSeconds / 60)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 { return "em \(days)d\(hours)h" }
        if hours > 0 { return "em \(hours)h\(minutes)m" }
        return "em \(minutes)m"
    }
}
