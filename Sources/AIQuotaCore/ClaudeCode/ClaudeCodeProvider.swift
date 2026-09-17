import Foundation

/// Wraps the existing (and already tested) `ClaudeCodeLogReader` / `FiveHourBlockBuilder` /
/// `CostCalculator` pipeline behind the `QuotaProvider` protocol. No behavior changes here —
/// this is purely an adapter so Claude Code shows up alongside the other providers.
public struct ClaudeCodeProvider: QuotaProvider {
    public let id = "claude-code"
    public let displayName = "Claude Code"
    public let kind: ProviderDataKind = .fullTokens

    private let reader: ClaudeCodeLogReader

    public init(reader: ClaudeCodeLogReader = ClaudeCodeLogReader()) {
        self.reader = reader
    }

    public var sourcePath: String { reader.projectsDirectory.path }

    public var isInstalled: Bool {
        FileManager.default.fileExists(atPath: sourcePath)
    }

    public func snapshot(config: QuotaConfig) throws -> ProviderSnapshot {
        guard isInstalled else {
            return .unavailable(
                providerId: id, displayName: displayName, isInstalled: false,
                note: "Diretório \(sourcePath) não encontrado"
            )
        }

        let events = reader.readAllEvents()
        guard let block = FiveHourBlockBuilder.buildBlocks(from: events).last else {
            return .unavailable(
                providerId: id, displayName: displayName, isInstalled: true,
                note: "Nenhum evento de uso encontrado em \(sourcePath)"
            )
        }

        let byModel = block.eventsByModel.map { model, events -> ProviderModelUsage in
            ProviderModelUsage(
                model: model,
                totalTokens: events.reduce(0) { $0 + $1.totalTokens },
                eventCount: events.count,
                cost: CostCalculator.totalCost(for: events),
                isEstimatedPricing: ModelPricingTable.pricing(for: model).isEstimated
            )
        }.sorted { ($0.cost ?? 0) > ($1.cost ?? 0) }

        return ProviderSnapshot(
            providerId: id,
            displayName: displayName,
            kind: .fullTokens,
            isInstalled: true,
            windowStart: block.start,
            windowEnd: block.end,
            isActive: block.isActive(),
            totalTokens: block.totalTokens,
            totalCost: block.totalCost,
            eventCount: block.events.count,
            byModel: byModel,
            officialLimit: nil,
            note: nil
        )
    }
}
