import Foundation

/// Resolve a janela de cota *de verdade* — a que o provedor oficialmente está contando — em vez
/// da janela inferida dos logs locais.
///
/// Por que isso importa: `UsageWindowBuilder` abre a janela na hora cheia do PRIMEIRO evento
/// local. É uma inferência razoável quando não há nada melhor, mas não é a janela que a Anthropic
/// conta: se você ficou 40 min sem rodar nada depois do reset, a janela inferida começa 40 min
/// atrasada — e some do painel 40 min depois da hora real de reset.
///
/// Quando existe um `resets_at` oficial, a janela real é exatamente `[resets_at - duração, resets_at)`,
/// sem arredondamento e sem chute. E esse dado continua confiável **no exato momento em que o
/// endpoint está defasado**: na virada ele devolve o `resets_at` NOVO junto com o percentual
/// VELHO. É o percentual que mente, nunca a hora de reset. Ancorar a contagem no `resets_at` é o
/// que torna a contagem de tokens imune à defasagem, sem precisar de relógio nenhum.
public enum AuthoritativeWindow {
    public struct Resolved: Equatable, Sendable {
        public let window: UsageWindow
        /// `true` quando a janela veio de um `resets_at` oficial; `false` quando foi inferida dos
        /// logs locais, por não haver limite oficial disponível.
        public let isOfficial: Bool
    }

    /// Rótulos que representam a janela de sessão, nos nomes que cada leitor usa.
    static let sessionLabels: Set<String> = ["5h", "sessão", "sessao", "primary"]
    /// Rótulos da janela semanal.
    static let weeklyLabels: Set<String> = ["semanal", "weekly", "7d", "secondary"]

    /// Duração da janela que um rótulo representa — usada para reconstruir o início a partir do
    /// `resets_at`. `nil` para rótulo desconhecido (provedor customizado), que então não tem
    /// janela reconstruível.
    public static func duration(forLabel label: String) -> TimeInterval? {
        let key = label.lowercased()
        if sessionLabels.contains(key) { return UsageWindowBuilder.windowDuration }
        if weeklyLabels.contains(key) { return 7 * 86_400 }
        return nil
    }

    /// A janela de SESSÃO: do `resets_at` oficial quando houver um válido, senão a última janela
    /// inferida dos logs. `nil` quando não há nem oficial nem evento nenhum.
    public static func resolve<T: TimestampedEvent>(
        officialLimits: [OfficialLimitInfo],
        events: [T],
        now: Date
    ) -> Resolved? {
        let session = officialLimits.first { sessionLabels.contains($0.label.lowercased()) }
        if let resetsAt = session?.resetsAt, resetsAt > now {
            let duration = UsageWindowBuilder.windowDuration
            return Resolved(
                window: UsageWindow(start: resetsAt.addingTimeInterval(-duration), duration: duration),
                isOfficial: true
            )
        }
        guard let inferred = UsageWindowBuilder.windows(for: events).last?.window else { return nil }
        return Resolved(window: inferred, isOfficial: false)
    }

    /// A janela que um limite oficial qualquer descreve (sessão ou semanal), reconstruída do seu
    /// `resets_at`. `nil` quando o rótulo é desconhecido ou não há `resets_at`.
    public static func window(for limit: OfficialLimitInfo) -> UsageWindow? {
        guard let resetsAt = limit.resetsAt, let duration = duration(forLabel: limit.label) else { return nil }
        return UsageWindow(start: resetsAt.addingTimeInterval(-duration), duration: duration)
    }

    /// Os eventos que caem DENTRO da janela — a contagem real, medida nos logs locais.
    public static func events<T: TimestampedEvent>(_ events: [T], in window: UsageWindow) -> [T] {
        events.filter { $0.timestamp >= window.start && $0.timestamp < window.end }
    }
}
