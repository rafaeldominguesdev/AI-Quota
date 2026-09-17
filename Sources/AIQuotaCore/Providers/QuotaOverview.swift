import Foundation

/// The multi-provider aggregate: every configured provider's snapshot, plus which one is
/// "primary" (the one shown on the menu bar gauge — configurable via `providers.json`,
/// defaulting to Claude Code).
///
/// Note for future readers: the original single-provider `QuotaSnapshot` (Claude-Code-only) is
/// intentionally left untouched alongside this type, since `Sources/AIQuota` (the menu bar UI)
/// already depends on its exact shape. `QuotaOverview` is the new, provider-agnostic aggregate;
/// the CLI and any future UI work should build on this one instead.
public struct QuotaOverview: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let primaryProviderId: String
    public let providers: [ProviderSnapshot]
    /// Messages for custom providers in `providers.json` that were malformed and got skipped.
    public let configWarnings: [String]

    public init(generatedAt: Date, primaryProviderId: String, providers: [ProviderSnapshot], configWarnings: [String]) {
        self.generatedAt = generatedAt
        self.primaryProviderId = primaryProviderId
        self.providers = providers
        self.configWarnings = configWarnings
    }

    public var primary: ProviderSnapshot? {
        providers.first { $0.providerId == primaryProviderId } ?? providers.first
    }
}
