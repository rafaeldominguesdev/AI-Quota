import Foundation

/// Configuração usada para calcular o percentual de uso exibido na UI.
public struct QuotaConfig: Equatable, Sendable {
    /// Teto de custo (USD) usado como referência de 100% de uso do bloco de 5h.
    ///
    /// IMPORTANTE: isso NÃO é um limite oficial documentado pela Anthropic — é apenas
    /// um valor de referência razoável para dar ao usuário uma noção de "quanto já gastei
    /// nesse bloco". O usuário pode e deve poder ajustar esse valor na UI.
    public var referenceCostCeilingUSD: Double

    /// Percentual (0-100) a partir do qual o estado vira "warning".
    public var warningThresholdPercent: Double
    /// Percentual (0-100) a partir do qual o estado vira "danger".
    public var dangerThresholdPercent: Double

    public init(
        referenceCostCeilingUSD: Double = 50.0,
        warningThresholdPercent: Double = 50.0,
        dangerThresholdPercent: Double = 80.0
    ) {
        self.referenceCostCeilingUSD = referenceCostCeilingUSD
        self.warningThresholdPercent = warningThresholdPercent
        self.dangerThresholdPercent = dangerThresholdPercent
    }

    public static let defaultConfig = QuotaConfig()
}
