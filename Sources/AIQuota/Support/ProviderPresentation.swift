import AppKit
import SwiftUI
import AIQuotaCore

/// Nível de uso já traduzido para a linguagem da interface: rótulo em caixa alta + cor de estado.
enum UsageLevel {
    case calm
    case attention
    case critical

    /// Semáforo de verdade — verde/âmbar/vermelho — em vez da escada de brilho em cinza do
    /// PilotDeck original (ver `Theme.calm`/`Theme.warn` para o porquê do desvio).
    var color: Color {
        switch self {
        case .calm: return Theme.calm
        case .attention: return Theme.warn
        case .critical: return Theme.danger
        }
    }

    var nsColor: NSColor {
        switch self {
        case .calm: return Theme.NS.calm
        case .attention: return Theme.NS.warn
        case .critical: return Theme.NS.danger
        }
    }

    static func from(percent: Double, config: QuotaConfig = .defaultConfig) -> UsageLevel {
        if percent >= config.dangerThresholdPercent { return .critical }
        if percent >= config.warningThresholdPercent { return .attention }
        return .calm
    }
}

/// Uma janela de cota isolada dentro de um provedor — "5h", "Semanal" etc. Cada provedor pode
/// mostrar mais de uma (Codex reporta `primary` + `secondary` de verdade); quem não reporta
/// nenhuma janela oficial cai numa única janela estimada por custo, quando há custo para estimar.
struct QuotaWindowPresentation: Identifiable {
    let label: String
    let percent: Double
    let isOfficial: Bool
    let resetsAt: Date?
    private let config: QuotaConfig

    var id: String { label }
    var level: UsageLevel { UsageLevel.from(percent: percent, config: config) }
    var color: Color { level.color }

    init(label: String, percent: Double, isOfficial: Bool, resetsAt: Date?, config: QuotaConfig) {
        self.label = label
        self.percent = percent
        self.isOfficial = isOfficial
        self.resetsAt = resetsAt
        self.config = config
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

    /// Toda janela de cota do provedor, na ordem em que deve aparecer na UI. Prefere SEMPRE os
    /// limites oficiais (dado medido, um por janela reportada). Quando não há um limite oficial
    /// de SESSÃO especificamente — nunca existiu, ou existia mas estava expirado e foi
    /// descartado por quem lê o cache (ver `ClaudeAccountReader`, que apaga `resets_at` no
    /// passado) — completamos com uma estimativa por custo local, calculada na hora a partir dos
    /// eventos reais: é sempre fresca, ainda que menos precisa que o número oficial. Sem essa
    /// estimativa (e sem nenhum oficial), a lista vem vazia e a UI mostra o traço.
    var windows: [QuotaWindowPresentation] {
        var result = snapshot.officialLimits.map { info in
            QuotaWindowPresentation(
                label: info.label,
                percent: min(100, max(0, info.usedPercent)),
                isOfficial: true,
                resetsAt: info.resetsAt,
                config: config
            )
        }

        let hasSessionWindow = result.contains { Self.isSessionLabel($0.label) }
        if !hasSessionWindow, let cost = snapshot.totalCost, cost > 0 {
            result.insert(
                QuotaWindowPresentation(
                    label: Self.estimatedWindowLabel(for: snapshot.providerId),
                    percent: min(100, cost / config.referenceCostCeilingUSD * 100),
                    isOfficial: false,
                    resetsAt: snapshot.isActive ? snapshot.windowEnd : nil,
                    config: config
                ),
                at: 0
            )
        }

        return result
    }

    /// Rótulo da janela estimada por custo — só o Claude Code passa por aqui hoje, e a janela que
    /// ele mede é sempre o bloco de 5h.
    private static func estimatedWindowLabel(for providerId: String) -> String {
        providerId == "claude-code" ? "5h" : "Uso"
    }

    /// Só as janelas de sessão (curta duração — "5h", "45min"...), sem as diárias/semanais. É o
    /// que a barra de menu mostra: de relance, só interessa a cota que reseta em horas, não a
    /// que reseta em dias — essa fica só no painel.
    var sessionWindows: [QuotaWindowPresentation] {
        windows.filter { Self.isSessionLabel($0.label) }
    }

    private static func isSessionLabel(_ label: String) -> Bool {
        let normalized = label.lowercased()
        return normalized.hasSuffix("h") || normalized.hasSuffix("min")
    }

    /// Percentual "representativo" do provedor: o da primeira janela, quando há alguma. Usado
    /// pela barra de menu e pelo cabeçalho do painel, que só têm espaço para um número.
    var percent: Double? { windows.first?.percent }

    /// `true` quando `percent` veio do próprio provedor, e não do nosso cálculo de custo.
    var isPercentOfficial: Bool { windows.first?.isOfficial ?? false }

    var level: UsageLevel? { windows.first?.level }

    /// Cor de estado da linha: nível de uso quando houver, senão a "saúde" do provedor.
    var accent: Color {
        if snapshot.kind == .unavailable { return Theme.inkFaint }
        if let level { return level.color }
        return snapshot.isActive ? Theme.inkDim : Theme.inkMuted
    }

    /// Rótulo curto do plano do provedor ("PLUS", "PRO"...), quando ele reporta um. `nil` para
    /// quem não expõe essa informação localmente — a UI simplesmente não desenha o selo.
    var planBadge: String? {
        guard let label = snapshot.planLabel?.trimmingCharacters(in: .whitespaces), !label.isEmpty else { return nil }
        return label.uppercased()
    }

    /// A primeira letra do plano ("PLUS" → "P", "MAX" → "M"), para o indicador quadrado ao lado
    /// do e-mail da conta.
    var planBadgeLetter: String? {
        planBadge?.first.map(String.init)
    }

    /// Conectada de verdade = instalada E com conta logada legível OU com alguma janela de cota.
    /// Grok (instalado, sem login nem cota legível por nenhum meio) conta como NÃO conectado —
    /// vai para a aba de conectar, não para a lista principal. Cursor tem conta legível
    /// (`CursorAccountReader`) mesmo sem cota, então entra como conectado assim que loga.
    var isConnected: Bool {
        snapshot.isInstalled && (maskedAccountEmail != nil || !windows.isEmpty)
    }

    /// E-mail da conta mascarado ("r•••@g•••.com"), quando o provedor guarda credenciais
    /// legíveis localmente. `nil` para quem não guarda (Grok, Cursor...) — a UI simplesmente não
    /// desenha a linha.
    var maskedAccountEmail: String? {
        snapshot.accountEmail.map(QuotaFormatting.maskedEmail)
    }

    /// O que mostrar no lugar da barra quando não há percentual: o dado que o provedor tem, ou
    /// `nil` quando ele não tem nenhum (aí a linha só mostra o traço).
    var fallbackValue: String? {
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

    /// Momento em que a janela reinicia: o da primeira janela de cota, quando existir. `nil`
    /// quando não há nenhuma janela ativa (não faz sentido contar para trás).
    var resetsAt: Date? { windows.first?.resetsAt }

    /// Explicação curta para casos de borda (não instalado, sem dado legível, erro de leitura).
    var note: String? {
        guard let note = snapshot.note, !note.isEmpty else { return nil }
        return note
    }
}
