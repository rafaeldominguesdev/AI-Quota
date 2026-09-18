import Foundation

/// Wraps the existing `CursorUsageReader` behind the `QuotaProvider` protocol. Cursor's database
/// has no token counts (confirmed in the original data-source survey) — only model + timestamp
/// per generated hash — so this is always `.countOnly`.
public struct CursorProvider: QuotaProvider {
    public let id = "cursor"
    public let displayName = "Cursor"
    public let kind: ProviderDataKind = .countOnly

    private let reader: CursorUsageReader

    public init(reader: CursorUsageReader = CursorUsageReader()) {
        self.reader = reader
    }

    public var sourcePath: String { reader.databasePath }

    public var isInstalled: Bool {
        FileManager.default.fileExists(atPath: sourcePath)
    }

    public func snapshot(config: QuotaConfig) throws -> ProviderSnapshot {
        guard isInstalled else {
            return .unavailable(
                providerId: id, displayName: displayName, isInstalled: false,
                note: "Banco \(sourcePath) não encontrado"
            )
        }

        let records = reader.readUsageRecords()
        guard let last = UsageWindowBuilder.windows(for: records).last else {
            return .unavailable(
                providerId: id, displayName: displayName, kind: .countOnly, isInstalled: true,
                note: "Nenhum uso registrado em \(sourcePath)"
            )
        }

        let byModel = Dictionary(grouping: last.events, by: { $0.model })
            .map { model, records in
                ProviderModelUsage(model: model, totalTokens: 0, eventCount: records.count, cost: nil, isEstimatedPricing: false)
            }
            .sorted { $0.eventCount > $1.eventCount }

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
            eventCount: last.events.count,
            byModel: byModel,
            note: "Sem dado de token: o Cursor só registra quantas vezes cada modelo foi usado.",
            hourlyUsage: hourlyUsage
        )
    }
}
