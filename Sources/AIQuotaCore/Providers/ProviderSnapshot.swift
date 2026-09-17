import Foundation

/// Usage broken down by model within a provider's current window.
public struct ProviderModelUsage: Codable, Equatable, Sendable {
    public let model: String
    public let totalTokens: Int
    public let eventCount: Int
    public let cost: Double?
    public let isEstimatedPricing: Bool

    public init(model: String, totalTokens: Int, eventCount: Int, cost: Double?, isEstimatedPricing: Bool) {
        self.model = model
        self.totalTokens = totalTokens
        self.eventCount = eventCount
        self.cost = cost
        self.isEstimatedPricing = isEstimatedPricing
    }
}

/// An officially-reported limit (straight from the provider's own rate-limit payload), when one
/// is available — always preferable to our own cost-based estimate.
public struct OfficialLimitInfo: Codable, Equatable, Sendable {
    public let label: String
    public let usedPercent: Double
    public let resetsAt: Date?

    public init(label: String, usedPercent: Double, resetsAt: Date?) {
        self.label = label
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
    }
}

/// A single provider's usage snapshot for its current window.
public struct ProviderSnapshot: Codable, Equatable, Sendable {
    public let providerId: String
    public let displayName: String
    public let kind: ProviderDataKind
    public let isInstalled: Bool

    public let windowStart: Date?
    public let windowEnd: Date?
    public let isActive: Bool

    public let totalTokens: Int
    public let totalCost: Double?
    public let eventCount: Int

    public let byModel: [ProviderModelUsage]

    /// Present only when the provider itself reports an official quota/rate limit (e.g. Codex's
    /// `rate_limits`). Never invented — nil means "no official limit found", not "zero used".
    public let officialLimit: OfficialLimitInfo?

    /// Human-readable explanation for edge cases: not installed, no data, config errors, etc.
    public let note: String?

    public init(
        providerId: String,
        displayName: String,
        kind: ProviderDataKind,
        isInstalled: Bool,
        windowStart: Date?,
        windowEnd: Date?,
        isActive: Bool,
        totalTokens: Int,
        totalCost: Double?,
        eventCount: Int,
        byModel: [ProviderModelUsage],
        officialLimit: OfficialLimitInfo?,
        note: String?
    ) {
        self.providerId = providerId
        self.displayName = displayName
        self.kind = kind
        self.isInstalled = isInstalled
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.isActive = isActive
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.eventCount = eventCount
        self.byModel = byModel
        self.officialLimit = officialLimit
        self.note = note
    }

    /// Convenience for the common "nothing to show" case (not installed, or installed but no
    /// readable data yet).
    public static func unavailable(
        providerId: String,
        displayName: String,
        kind: ProviderDataKind = .unavailable,
        isInstalled: Bool,
        note: String
    ) -> ProviderSnapshot {
        ProviderSnapshot(
            providerId: providerId,
            displayName: displayName,
            kind: kind,
            isInstalled: isInstalled,
            windowStart: nil,
            windowEnd: nil,
            isActive: false,
            totalTokens: 0,
            totalCost: nil,
            eventCount: 0,
            byModel: [],
            officialLimit: nil,
            note: note
        )
    }
}
