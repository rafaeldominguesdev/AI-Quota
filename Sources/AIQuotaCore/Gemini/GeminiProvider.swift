import Foundation

/// Reads `~/.gemini/antigravity-cli/history.jsonl`. No token data is available anywhere under
/// `~/.gemini` (confirmed by grepping for `usageMetadata`/`totalTokenCount`/`promptTokenCount`),
/// so this provider only counts interactions per window.
public struct GeminiProvider: QuotaProvider {
    public let id = "gemini"
    public let displayName = "Gemini"
    public let kind: ProviderDataKind = .countOnly

    private let historyFile: URL

    public init(
        historyFile: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini/antigravity-cli/history.jsonl")
    ) {
        self.historyFile = historyFile
    }

    public var sourcePath: String { historyFile.path }

    public var isInstalled: Bool {
        let geminiHome = historyFile
            .deletingLastPathComponent() // antigravity-cli
            .deletingLastPathComponent() // .gemini
        return FileManager.default.fileExists(atPath: geminiHome.path)
    }

    public func snapshot(config: QuotaConfig) throws -> ProviderSnapshot {
        guard isInstalled else {
            return .unavailable(
                providerId: id, displayName: displayName, isInstalled: false,
                note: "Diretório ~/.gemini não encontrado"
            )
        }
        guard FileManager.default.fileExists(atPath: sourcePath) else {
            return .unavailable(
                providerId: id, displayName: displayName, kind: .countOnly, isInstalled: true,
                note: "Arquivo \(sourcePath) não encontrado"
            )
        }

        let events = GeminiHistoryReader.parseFile(at: historyFile)
        guard let last = UsageWindowBuilder.windows(for: events).last else {
            return .unavailable(
                providerId: id, displayName: displayName, kind: .countOnly, isInstalled: true,
                note: "Nenhuma interação encontrada em \(sourcePath)"
            )
        }

        let count = last.events.count
        let hourlyUsage = UsageWindowBuilder.hourlyBuckets(for: last.events, window: last.window) { _ in 1 }
        return ProviderSnapshot(
            providerId: id,
            displayName: displayName,
            kind: .countOnly,
            isInstalled: true,
            windowStart: last.window.start,
            windowEnd: last.window.end,
            isActive: last.window.isActive(),
            totalTokens: 0,
            totalCost: nil,
            eventCount: count,
            byModel: [
                ProviderModelUsage(model: "desconhecido", totalTokens: 0, eventCount: count, cost: nil, isEstimatedPricing: false)
            ],
            note: "Sem dado de token: o histórico local do Gemini só registra interações, não tokens.",
            hourlyUsage: hourlyUsage
        )
    }
}
