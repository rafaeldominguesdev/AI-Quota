import Foundation

/// Configuração usada para calcular o percentual de uso exibido na UI.
public struct QuotaConfig: Equatable, Sendable {
    /// Teto de custo (USD) usado como referência de 100% de uso do bloco de 5h.
    ///
    /// IMPORTANTE: isso NÃO é um limite oficial documentado pela Anthropic — é apenas
    /// um valor de referência razoável para dar ao usuário uma noção de "quanto já gastei
    /// nesse bloco". O usuário pode e deve poder ajustar esse valor na UI.
    public var referenceCostCeilingUSD: Double

    /// Teto de USOS (não tokens, o Cursor não expõe isso) usado como referência de 100% do mês
    /// corrente, quando não há leitura da % real do dashboard (ver `CursorWebUsageCache`).
    ///
    /// IMPORTANTE: também NÃO é um limite oficial — o Cursor migrou para cobrança por
    /// consumo e não publica mais uma contagem fixa de requests por plano. É só uma referência
    /// razoável (equivalente ao plano Pro antigo) para dar alguma noção de progresso no mês
    /// sem precisar logar na web.
    public var cursorMonthlyEventCeiling: Double

    /// Percentual (0-100) a partir do qual o estado vira "warning".
    public var warningThresholdPercent: Double
    /// Percentual (0-100) a partir do qual o estado vira "danger".
    public var dangerThresholdPercent: Double

    public init(
        referenceCostCeilingUSD: Double = 50.0,
        cursorMonthlyEventCeiling: Double = 500.0,
        warningThresholdPercent: Double = 50.0,
        dangerThresholdPercent: Double = 80.0
    ) {
        self.referenceCostCeilingUSD = referenceCostCeilingUSD
        self.cursorMonthlyEventCeiling = cursorMonthlyEventCeiling
        self.warningThresholdPercent = warningThresholdPercent
        self.dangerThresholdPercent = dangerThresholdPercent
    }

    public static let defaultConfig = QuotaConfig()
}
