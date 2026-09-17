import Foundation

/// `~/.grok` was confirmed to contain only configuration (`settings.json`, `user-settings.json`)
/// — no sessions, history, or logs of any kind. There is nothing to read, so this provider is
/// always `.unavailable`; the only thing worth reporting is whether the CLI itself is installed.
public struct GrokProvider: QuotaProvider {
    public let id = "grok"
    public let displayName = "Grok"
    public let kind: ProviderDataKind = .unavailable

    private let grokHome: URL

    public init(grokHome: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".grok")) {
        self.grokHome = grokHome
    }

    public var sourcePath: String { grokHome.path }

    public var isInstalled: Bool {
        FileManager.default.fileExists(atPath: sourcePath)
    }

    public func snapshot(config: QuotaConfig) throws -> ProviderSnapshot {
        guard isInstalled else {
            return .unavailable(
                providerId: id, displayName: displayName, isInstalled: false,
                note: "Diretório ~/.grok não encontrado"
            )
        }
        return .unavailable(
            providerId: id, displayName: displayName, isInstalled: true,
            note: "O Grok CLI não registra uso local — ~/.grok só tem configurações (settings.json), sem sessões nem histórico."
        )
    }
}
