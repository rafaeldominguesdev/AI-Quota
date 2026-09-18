import Foundation

/// Lê a conta logada do Claude Code em `~/.claude.json` (`oauthAccount`), e também o limite
/// oficial de uso que o próprio CLI cacheia ali (`cachedUsageUtilization`) — a cada vez que o
/// Claude Code roda, ele salva o percentual usado das janelas de 5h e semanal que a Anthropic
/// devolveu. Não inventamos nada, só lemos o que o CLI já escreveu.
public struct ClaudeAccountReader: Sendable {
    public struct Account: Equatable, Sendable {
        public let email: String?
        /// "claude_pro", "claude_max"... — vira o rótulo curto de plano na UI.
        public let organizationType: String?
        /// Vazio quando o CLI ainda não cacheou nenhum utilization (instalação muito nova) — aí
        /// quem chama cai de volta pra estimativa por custo.
        public let officialLimits: [OfficialLimitInfo]
    }

    private let configFile: URL
    private let now: @Sendable () -> Date

    public init(
        configFile: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude.json"),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.configFile = configFile
        self.now = now
    }

    public func read() -> Account? {
        guard let data = try? Data(contentsOf: configFile),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauthAccount = root["oauthAccount"] as? [String: Any] else {
            return nil
        }
        return Account(
            email: oauthAccount["emailAddress"] as? String,
            organizationType: oauthAccount["organizationType"] as? String,
            officialLimits: Self.officialLimits(root: root, now: now())
        )
    }

    /// `cachedUsageUtilization.utilization.five_hour`/`.seven_day` — a mesma dupla de janelas
    /// (sessão + semanal) que o Codex reporta em `rate_limits`, só que sob nomes diferentes. A
    /// ordem importa: a primeira entrada é a mais urgente (usada como percentual único da barra
    /// de menu e do cabeçalho), então a sessão vem antes da semanal.
    ///
    /// O Claude Code só regrava esse cache quando roda de novo — se a pessoa ficar um tempo sem
    /// abrir o CLI, `resets_at` fica no passado e o percentual (às vezes 100%) congela lá,
    /// mentindo que a janela ainda está travada mesmo depois de já ter resetado de verdade.
    /// Descartamos qualquer entrada cujo reset já passou: é melhor a janela sumir do painel (até
    /// o CLI rodar de novo e regravar) do que mostrar uma cota "crítica" que na real já zerou.
    private static func officialLimits(root: [String: Any], now: Date) -> [OfficialLimitInfo] {
        guard let cached = root["cachedUsageUtilization"] as? [String: Any],
              let utilization = cached["utilization"] as? [String: Any] else {
            return []
        }
        let fiveHour = (utilization["five_hour"] as? [String: Any]).flatMap { parseEntry($0, label: "5h", now: now) }
        let sevenDay = (utilization["seven_day"] as? [String: Any]).flatMap { parseEntry($0, label: "semanal", now: now) }
        return [fiveHour, sevenDay].compactMap { $0 }
    }

    private static func parseEntry(_ entry: [String: Any], label: String, now: Date) -> OfficialLimitInfo? {
        guard let percent = (entry["utilization"] as? NSNumber)?.doubleValue else { return nil }
        let resetsAt = (entry["resets_at"] as? String).flatMap(ISO8601Parsing.date(from:))
        if let resetsAt, resetsAt <= now { return nil }
        return OfficialLimitInfo(label: label, usedPercent: percent, resetsAt: resetsAt)
    }
}
