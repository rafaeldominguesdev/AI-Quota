import AppKit
import SwiftUI
import AIQuotaCore

/// Nível de uso já traduzido para a linguagem da interface: rótulo em caixa alta + cor de estado.
enum UsageLevel {
    case calm
    case attention
    case critical

    var label: String {
        switch self {
        case .calm: return "Tranquilo"
        case .attention: return "Atenção"
        case .critical: return "Crítico"
        }
    }

    var color: Color {
        switch self {
        case .calm: return Theme.success
        case .attention: return Theme.role
        case .critical: return Theme.danger
        }
    }

    var nsColor: NSColor {
        switch self {
        case .calm: return Theme.NS.success
        case .attention: return Theme.NS.role
        case .critical: return Theme.NS.danger
        }
    }

    static func from(percent: Double, config: QuotaConfig = .defaultConfig) -> UsageLevel {
        if percent >= config.dangerThresholdPercent { return .critical }
        if percent >= config.warningThresholdPercent { return .attention }
        return .calm
    }
}

/// Tudo que a interface precisa saber sobre um `ProviderSnapshot`, derivado uma única vez:
/// qual percentual mostrar (e se ele é oficial ou estimado), qual o valor principal da linha,
/// qual badge de qualidade de dado, e o que fazer quando algum desses dados simplesmente não
/// existe — nesse caso o campo vira `nil` e a UI encolhe, em vez de exibir "0" ou "nil" cru.
struct ProviderPresentation {
    let snapshot: ProviderSnapshot
    let isPrimary: Bool

    init(snapshot: ProviderSnapshot, isPrimary: Bool, config: QuotaConfig = .defaultConfig) {
        self.snapshot = snapshot
        self.isPrimary = isPrimary
        self.config = config
    }

    private let config: QuotaConfig

    var id: String { snapshot.providerId }
    var displayName: String { snapshot.displayName }

    /// Percentual de consumo da janela. Prefere SEMPRE o limite oficial do provedor: ele é dado
    /// medido, não estimativa nossa. Sem limite oficial, cai para o custo em relação ao teto de
    /// referência; sem custo, não há percentual nenhum e a UI omite a barra.
    var percent: Double? {
        if let official = snapshot.officialLimit {
            return min(100, max(0, official.usedPercent))
        }
        guard let cost = snapshot.totalCost, cost > 0 else { return nil }
        return min(100, cost / config.referenceCostCeilingUSD * 100)
    }

    /// `true` quando `percent` veio do próprio provedor, e não do nosso cálculo de custo.
    var isPercentOfficial: Bool { snapshot.officialLimit != nil }

    var level: UsageLevel? {
        percent.map { UsageLevel.from(percent: $0, config: config) }
    }

    /// Cor de estado da linha: nível de uso quando houver, senão a "saúde" do provedor.
    var accent: Color {
        if snapshot.kind == .unavailable { return Theme.inkFaint }
        if let level { return level.color }
        return snapshot.isActive ? Theme.tok : Theme.inkMuted
    }

    var kindBadge: String {
        switch snapshot.kind {
        case .fullTokens: return "Tokens"
        case .tokensOnly: return "Parcial"
        case .countOnly: return "Contagem"
        case .unavailable: return "Indisponível"
        }
    }

    /// Valor mais importante daquele provedor, já formatado — ou `nil` quando não há nada
    /// confiável para mostrar.
    var primaryValue: String? {
        switch snapshot.kind {
        case .fullTokens, .tokensOnly:
            guard snapshot.totalTokens > 0 else { return nil }
            return QuotaFormatting.compactTokens(snapshot.totalTokens) + " tok"
        case .countOnly:
            guard snapshot.eventCount > 0 else { return nil }
            return "\(snapshot.eventCount) uso" + (snapshot.eventCount == 1 ? "" : "s")
        case .unavailable:
            return nil
        }
    }

    var cost: Double? {
        guard let cost = snapshot.totalCost, cost > 0 else { return nil }
        return cost
    }

    /// Momento em que a janela reinicia: o do limite oficial quando existir, senão o fim da
    /// janela local. `nil` quando a janela já encerrou (não faz sentido contar para trás).
    var resetsAt: Date? {
        if let official = snapshot.officialLimit?.resetsAt { return official }
        guard snapshot.isActive else { return nil }
        return snapshot.windowEnd
    }

    var hourlyUsage: [Int] {
        snapshot.hourlyUsage.contains(where: { $0 > 0 }) ? snapshot.hourlyUsage : []
    }

    var isExpandable: Bool { !snapshot.byModel.isEmpty }

    /// Explicação curta para casos de borda (não instalado, sem dado legível, erro de leitura).
    var note: String? {
        guard let note = snapshot.note, !note.isEmpty else { return nil }
        return note
    }
}
