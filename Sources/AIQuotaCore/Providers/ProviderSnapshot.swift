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

    /// Usage split into one bucket per hour of the window (always
    /// `UsageWindowBuilder.hourlySlotCount` entries), so the UI can draw a sparkline of *when*
    /// the window was burned, not just how much. Holds tokens for token-capable providers and
    /// event counts for `.countOnly` ones; empty when there is nothing to plot.
    public let hourlyUsage: [Int]

    /// Uma janela de rate-limit oficial por entrada (e.g. Codex reporta `primary` + `secondary`
    /// separadamente). Nunca inventado — array vazio significa "nenhum limite oficial encontrado",
    /// nunca "zero usado". A ordem importa: a primeira entrada é a mais urgente/representativa
    /// (usada como o percentual único da barra de menu e do cabeçalho).
    public let officialLimits: [OfficialLimitInfo]

    /// Rótulo curto do plano do provedor (ex.: "plus", "pro"), quando ele reporta um. `nil` para
    /// provedores que não expõem essa informação localmente.
    public let planLabel: String?

    /// E-mail da conta logada localmente, sem máscara — quem mascara é a UI, nunca o dado bruto.
    /// `nil` para quem não expõe identidade nenhuma localmente ou por CLI (Grok).
    public let accountEmail: String?

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
        officialLimits: [OfficialLimitInfo] = [],
        note: String?,
        hourlyUsage: [Int] = [],
        planLabel: String? = nil,
        accountEmail: String? = nil
    ) {
        self.providerId = providerId
        self.displayName = displayName
        self.kind = kind
        self.isInstalled = isInstalled
        self.accountEmail = accountEmail
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.isActive = isActive
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.eventCount = eventCount
        self.byModel = byModel
        self.officialLimits = officialLimits
        self.note = note
        self.hourlyUsage = hourlyUsage
        self.planLabel = planLabel
    }

    /// Convenience for the common "nothing to show" case (not installed, or installed but no
    /// readable data yet).
    public static func unavailable(
        providerId: String,
        displayName: String,
        kind: ProviderDataKind = .unavailable,
        isInstalled: Bool,
        note: String,
        planLabel: String? = nil,
        accountEmail: String? = nil
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
            note: note,
            hourlyUsage: [],
            planLabel: planLabel,
            accountEmail: accountEmail
        )
    }
}
