import Foundation

/// Builds the full list of providers (built-in + custom, from `providers.json`) and knows how to
/// turn them into a `QuotaOverview`. A single provider throwing or misbehaving never takes down
/// the others — each `snapshot(config:)` call is individually guarded.
public struct ProviderRegistry: Sendable {
    public let providers: [any QuotaProvider]
    public let primaryProviderId: String
    /// Messages for malformed custom providers that were skipped — surfaced to the UI/CLI.
    public let configWarnings: [String]

    public init(configURL: URL = ProvidersConfigStore.defaultFile) {
        let parsed = ProvidersConfigStore.load(from: configURL)

        var list: [any QuotaProvider] = [
            ClaudeCodeProvider(),
            CodexProvider(),
            GeminiProvider(),
            GrokProvider(),
            CursorProvider()
        ]
        list.append(contentsOf: parsed.customProviders.map(CustomLogProvider.init(config:)))

        self.providers = list
        self.primaryProviderId = parsed.primaryProviderId ?? "claude-code"
        self.configWarnings = parsed.errors
    }

    public func buildOverview(config: QuotaConfig = .defaultConfig, now: Date = Date()) -> QuotaOverview {
        let snapshots: [ProviderSnapshot] = providers.map { provider in
            do {
                return try provider.snapshot(config: config)
            } catch {
                return .unavailable(
                    providerId: provider.id,
                    displayName: provider.displayName,
                    isInstalled: provider.isInstalled,
                    note: "Erro ao ler dados: \(error.localizedDescription)"
                )
            }
        }
        return QuotaOverview(generatedAt: now, primaryProviderId: primaryProviderId, providers: snapshots, configWarnings: configWarnings)
    }
}
