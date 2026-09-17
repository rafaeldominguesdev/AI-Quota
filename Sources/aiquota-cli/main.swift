import AIQuotaCore
import Foundation

let arguments = CommandLine.arguments
let printAsJSON = arguments.contains("--json")

let reader = ClaudeCodeLogReader()
let events = reader.readAllEvents()

guard let snapshot = QuotaSnapshotBuilder.build(from: events) else {
    if printAsJSON {
        print("{\"error\":\"nenhum evento de uso encontrado em ~/.claude/projects\"}")
    } else {
        print("Nenhum dado de uso do Claude Code encontrado em ~/.claude/projects.")
    }
    exit(0)
}

if printAsJSON {
    printJSON(snapshot)
} else {
    printHuman(snapshot)
}

func printJSON(_ snapshot: QuotaSnapshot) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(snapshot), let json = String(data: data, encoding: .utf8) else {
        print("{\"error\":\"falha ao serializar snapshot\"}")
        return
    }
    print(json)
}

func printHuman(_ snapshot: QuotaSnapshot) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd/MM HH:mm"
    dateFormatter.timeZone = TimeZone.current

    print("AI Quota — janela de 5 horas do Claude Code")
    print(String(repeating: "-", count: 48))
    print("Status do bloco: \(snapshot.isActive ? "ativo" : "encerrado")")
    print("[\(progressBar(percent: snapshot.usagePercent))] \(formatted(snapshot.usagePercent))% (\(stateLabel(snapshot.state)))")
    print("Tokens usados: \(snapshot.totalTokens)")
    print("Custo estimado: US$ \(String(format: "%.2f", snapshot.totalCost))")
    print("Início do bloco: \(dateFormatter.string(from: snapshot.windowStart))")
    print("Reinicia às: \(dateFormatter.string(from: snapshot.resetAt)) (faltam \(snapshot.remainingTimeFormatted))")
    print("")
    print("Por modelo:")
    for entry in snapshot.byModel {
        let estimatedTag = entry.isEstimatedPricing ? " (preço estimado)" : ""
        let modelColumn = entry.model.padding(toLength: 30, withPad: " ", startingAt: 0)
        let tokensColumn = String(entry.totalTokens).leftPadded(to: 10)
        let costColumn = String(format: "%.2f", entry.cost)
        print("  \(modelColumn) \(tokensColumn) tokens   US$ \(costColumn)\(estimatedTag)")
    }
}

func progressBar(percent: Double, width: Int = 30) -> String {
    let filled = Int((percent / 100) * Double(width))
    let clampedFilled = max(0, min(width, filled))
    return String(repeating: "█", count: clampedFilled) + String(repeating: "░", count: width - clampedFilled)
}

func formatted(_ value: Double) -> String {
    String(format: "%.1f", value)
}

func stateLabel(_ state: QuotaState) -> String {
    switch state {
    case .safe: return "tranquilo"
    case .warning: return "atenção"
    case .danger: return "crítico"
    }
}

extension String {
    func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: " ", count: length - count) + self
    }
}
