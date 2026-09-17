import Foundation

/// A pluggable source of AI usage data (Claude Code, Codex, Gemini, Grok, Cursor, or a
/// user-defined custom provider from `providers.json`).
public protocol QuotaProvider: Sendable {
    /// Stable identifier, e.g. "claude-code". Used for config (`primaryProviderId`) and dedup.
    var id: String { get }
    var displayName: String { get }
    /// Quality of the data this provider can produce. May be a fixed value (Claude Code is
    /// always `.fullTokens`) or computed from what was actually configured/parsed (custom
    /// providers downgrade based on which JSON paths were supplied).
    var kind: ProviderDataKind { get }
    /// Whether the provider's directory/file/database exists on disk at all.
    var isInstalled: Bool { get }
    /// Path (or glob) checked on disk for this provider's data — shown by `aiquota-cli --providers`.
    var sourcePath: String { get }

    func snapshot(config: QuotaConfig) throws -> ProviderSnapshot
}
