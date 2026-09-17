import Foundation

public enum QuotaState: String, Codable, Sendable {
    case safe
    case warning
    case danger
}

public struct ModelUsageBreakdown: Codable, Equatable, Sendable {
    public let model: String
    public let totalTokens: Int
    public let cost: Double
    public let isEstimatedPricing: Bool
}

/// Resumo único do estado de uso, consumido pela UI (a ser feita em outra missão).
public struct QuotaSnapshot: Codable, Equatable, Sendable {
    public let generatedAt: Date

    public let windowStart: Date
    public let windowEnd: Date
    public let isActive: Bool

    /// Percentual (0-100) de `totalCost` em relação a `QuotaConfig.referenceCostCeilingUSD`.
    public let usagePercent: Double
    public let state: QuotaState

    public let totalTokens: Int
    public let totalCost: Double

    public let resetAt: Date
    public let remainingSeconds: TimeInterval
    public let remainingTimeFormatted: String

    public let byModel: [ModelUsageBreakdown]
}
