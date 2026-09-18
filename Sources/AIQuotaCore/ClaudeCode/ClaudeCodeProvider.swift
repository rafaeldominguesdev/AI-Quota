import Foundation

/// Wraps the existing (and already tested) `ClaudeCodeLogReader` / `FiveHourBlockBuilder` /
/// `CostCalculator` pipeline behind the `QuotaProvider` protocol. No behavior changes here —
/// this is purely an adapter so Claude Code shows up alongside the other providers.
public struct ClaudeCodeProvider: QuotaProvider {
    public let id: String
    public let displayName: String
    public let kind: ProviderDataKind = .fullTokens

    private let reader: ClaudeCodeLogReader
    private let accountReader: ClaudeAccountReader
    private let credentialsFile: URL

    /// `id`/`displayName` têm outro valor só para uma segunda (terceira...) conta descoberta por
    /// `MultiAccountDiscovery` — a conta padrão continua "claude-code"/"Claude Code". Idem
    /// `credentialsFile`: a conta extra tem o seu próprio `.credentials.json` dentro da própria
    /// pasta `.claude-<algo>`, separado do da conta padrão.
    public init(
        reader: ClaudeCodeLogReader = ClaudeCodeLogReader(),
        accountReader: ClaudeAccountReader = ClaudeAccountReader(),
        credentialsFile: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json"),
        id: String = "claude-code",
        displayName: String = "Claude Code"
    ) {
        self.reader = reader
        self.accountReader = accountReader
        self.credentialsFile = credentialsFile
        self.id = id
        self.displayName = displayName
    }

    /// "claude_pro" → "Pro", "claude_max" → "Max"... o prefixo "claude_" nunca aparece na UI.
    private static func planLabel(organizationType: String?) -> String? {
        guard let organizationType, organizationType.hasPrefix("claude_") else { return organizationType }
        return organizationType
            .dropFirst("claude_".count)
            .capitalized
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

        let hourlyUsage = UsageWindowBuilder.hourlyBuckets(
            for: block.events,
            window: UsageWindow(start: block.start),
            value: \.totalTokens
        )

        let account = accountReader.read()
        // Ao vivo primeiro (bate certo com claude.ai mesmo se o CLI não roda há dias); o cache
        // local de `~/.claude.json` (já filtrado por `ClaudeAccountReader` pra não mostrar janela
        // expirada) só entra se a rede falhar — offline, sem token, endpoint fora do ar etc.
        let officialLimits = ClaudeLiveUsageReader.read(credentialsFile: credentialsFile)
            ?? account?.officialLimits
            ?? []

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
            officialLimits: officialLimits,
            note: nil,
            hourlyUsage: hourlyUsage,
            planLabel: Self.planLabel(organizationType: account?.organizationType),
            accountEmail: account?.email
        )
    }
}
