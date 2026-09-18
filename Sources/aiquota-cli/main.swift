import AIQuotaCore
import Foundation

let arguments = CommandLine.arguments
let printAsJSON = arguments.contains("--json")
let listProvidersOnly = arguments.contains("--providers")

let registry = ProviderRegistry()

if listProvidersOnly {
    printProvidersList(registry)
    exit(0)
}

let overview = registry.buildOverview()

if printAsJSON {
    printJSON(overview)
} else {
    printHuman(overview)
}

// MARK: - --providers

func printProvidersList(_ registry: ProviderRegistry) {
    print("Provedores detectados")
    print(String(repeating: "-", count: 60))
    for provider in registry.providers {
        let installed = provider.isInstalled ? "instalado" : "não instalado"
        print("\(Formatting.padded(provider.displayName, to: 14)) \(Formatting.padded(provider.id, to: 14)) \(Formatting.padded(installed, to: 15)) \(Formatting.padded(provider.kind.rawValue, to: 12)) \(provider.sourcePath)")
    }
    print("")
    print("Principal (barra de menu): \(registry.primaryProviderId)")

    if !registry.configWarnings.isEmpty {
        print("")
        print("Avisos de providers.json:")
        for warning in registry.configWarnings {
            print("  - \(warning)")
        }
    }
}

// MARK: - --json

func printJSON(_ overview: QuotaOverview) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(overview), let json = String(data: data, encoding: .utf8) else {
        print("{\"error\":\"falha ao serializar overview\"}")
        return
    }
    print(json)
}

// MARK: - saída legível

func printHuman(_ overview: QuotaOverview) {
    print("AI Quota — uso por provedor")
    print(String(repeating: "=", count: 60))

    for provider in overview.providers {
        let marker = provider.providerId == overview.primaryProviderId ? " (principal)" : ""
        print("")
        print("== \(provider.displayName)\(marker) — \(provider.kind.rawValue) ==")
        printProviderBlock(provider)
    }

    if !overview.configWarnings.isEmpty {
        print("")
        print("Avisos de providers.json:")
        for warning in overview.configWarnings {
            print("  - \(warning)")
        }
    }
}

func printProviderBlock(_ provider: ProviderSnapshot) {
    print("Instalado: \(provider.isInstalled ? "sim" : "não")")

    guard provider.isInstalled else {
        if let note = provider.note { print(note) }
        return
    }

    guard let start = provider.windowStart, let end = provider.windowEnd else {
        if let note = provider.note { print(note) }
        return
    }

    let statusLabel = provider.isActive ? "ativa, faltam \(Formatting.remaining(until: end))" : "encerrada"
    print("Janela: \(Formatting.date(start)) – \(Formatting.date(end)) (\(statusLabel))")

    switch provider.kind {
    case .fullTokens, .tokensOnly:
        print("Tokens: \(Formatting.tokens(provider.totalTokens))")
        if let cost = provider.totalCost {
            print("Custo estimado: \(Formatting.cost(cost))")
        }
    case .countOnly:
        print("Sem dado de token — só contando interações.")
        print("Eventos na janela: \(provider.eventCount)")
    case .unavailable:
        break
    }

    for officialLimit in provider.officialLimits {
        var line = "Limite oficial: \(Formatting.percent(officialLimit.usedPercent)) usado (\(officialLimit.label))"
        if let resetsAt = officialLimit.resetsAt {
            line += " — reseta \(Formatting.date(resetsAt))"
        }
        print(line)
    }

    if !provider.byModel.isEmpty {
        print("Por modelo:")
        for entry in provider.byModel {
            var line = "  \(Formatting.padded(entry.model, to: 28)) "
            if provider.kind == .countOnly {
                line += "\(entry.eventCount) uso\(entry.eventCount == 1 ? "" : "s")"
            } else {
                line += "\(Formatting.tokens(entry.totalTokens)) tokens"
                if let cost = entry.cost {
                    line += "   \(Formatting.cost(cost))"
                    if entry.isEstimatedPricing { line += " (estimado)" }
                }
            }
            print(line)
        }
    }

    if let note = provider.note {
        print(note)
    }
}
