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
            AntigravityProvider(),
            GrokProvider(),
            CursorProvider()
        ]
        list.append(contentsOf: parsed.customProviders.map(CustomLogProvider.init(config:)))
        list.append(contentsOf: Self.discoveredAccountProviders())

        self.providers = list
        self.primaryProviderId = parsed.primaryProviderId ?? "claude-code"
        self.configWarnings = parsed.errors
    }

    /// Uma instância de `CodexProvider`/`ClaudeCodeProvider` a mais por conta extra encontrada
    /// por `MultiAccountDiscovery` — mesma lógica de leitura, só apontada pra outra pasta.
    private static func discoveredAccountProviders() -> [any QuotaProvider] {
        MultiAccountDiscovery.discover().map { account -> any QuotaProvider in
            let id = String(account.directory.lastPathComponent.dropFirst()) // ".codex-work" → "codex-work"
            switch account.kind {
            case .codex:
                return CodexProvider(
                    sessionsDirectory: account.directory.appendingPathComponent("sessions"),
                    accountReader: CodexAccountReader(authFile: account.directory.appendingPathComponent("auth.json")),
                    id: id,
                    displayName: "Codex (\(account.label.capitalized))"
                )
            case .claudeCode:
                return ClaudeCodeProvider(
                    reader: ClaudeCodeLogReader(projectsDirectory: account.directory.appendingPathComponent("projects")),
                    accountReader: ClaudeAccountReader(configFile: account.directory.appendingPathComponent(".claude.json")),
                    credentialsFile: account.directory.appendingPathComponent(".credentials.json"),
                    id: id,
                    displayName: "Claude Code (\(account.label.capitalized))"
                )
            }
        }
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
