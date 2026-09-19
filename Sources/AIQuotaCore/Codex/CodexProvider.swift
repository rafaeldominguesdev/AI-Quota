import Foundation

/// Reads `~/.codex/sessions/**/*.jsonl`. Despite what an earlier (wrong) pass at
/// docs/DATA-SOURCES.md said, Codex DOES report token usage locally — confirmed by inspecting
/// real session files: `event_msg` lines with `payload.type == "token_count"` carry both a
/// cumulative `total_token_usage` and a per-turn `last_token_usage`. We sum `last_token_usage`
/// deltas, never the cumulative counter (see `CodexSessionLine.swift` for why).
public struct CodexProvider: QuotaProvider {
    public let id: String
    public let displayName: String
    public let kind: ProviderDataKind = .fullTokens

    private let sessionsDirectory: URL
    private let accountReader: CodexAccountReader
    private let recentWindow: TimeInterval
    private let limitsWindow: TimeInterval
    private let now: @Sendable () -> Date

    /// Quantos bytes do FIM de uma sessão antiga lemos só para achar o rate limit mais recente
    /// dela, e quantas sessões antigas no máximo abrimos assim. Os dois números existem para o
    /// custo do refresh de 30s ficar limitado (há rollouts de 70+ MB no disco).
    private static let limitsTailBytes = 512 * 1024
    private static let limitsFileLimit = 8

    /// `id`/`displayName` têm outro valor só para uma segunda (terceira...) conta descoberta por
    /// `MultiAccountDiscovery` — a conta padrão continua "codex"/"Codex".
    ///
    /// `recentWindow` (padrão 24h): a soma de tokens só olha a janela de uso corrente, então
    /// arquivos de sessão não tocados há mais tempo que isso nem são abertos — sem isto, cada
    /// refresh de 30s reprocessava centenas de MB de sessões antigas à toa.
    ///
    /// `limitsWindow` (padrão 8 dias) é MAIOR de propósito: a cota semanal que o Codex reporta
    /// continua valendo dias depois do último uso, e antes disto quem passava um dia sem rodar o
    /// Codex via o provedor sumir inteiro do painel (nenhuma janela de cota → filtrado pela UI).
    /// Dessas sessões mais velhas lemos só o fim do arquivo, atrás do último rate limit.
    public init(
        sessionsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions"),
        accountReader: CodexAccountReader = CodexAccountReader(),
        id: String = "codex",
        displayName: String = "Codex",
        recentWindow: TimeInterval = 24 * 3600,
        limitsWindow: TimeInterval = 8 * 24 * 3600,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.sessionsDirectory = sessionsDirectory
        self.accountReader = accountReader
        self.id = id
        self.displayName = displayName
        self.recentWindow = recentWindow
        self.limitsWindow = limitsWindow
        self.now = now
    }

    public var sourcePath: String { sessionsDirectory.path }

    public var isInstalled: Bool {
        FileManager.default.fileExists(atPath: sessionsDirectory.deletingLastPathComponent().path)
    }

    public func snapshot(config: QuotaConfig) throws -> ProviderSnapshot {
        guard isInstalled else {
            return .unavailable(
                providerId: id, displayName: displayName, isInstalled: false,
                note: "Diretório ~/.codex não encontrado"
            )
        }

        let recentFiles = sessionFiles(modifiedAfter: now().addingTimeInterval(-recentWindow))

        var allEvents: [CodexTokenEvent] = []
        var latestModel: (timestamp: Date, model: String)?
        var latestRateLimits: (timestamp: Date, limits: CodexRateLimitsPayload)?

        for file in recentFiles {
            let parsed = CodexSessionParser.parseFile(at: file)
            allEvents.append(contentsOf: parsed.events)
            if let candidate = parsed.latestModel,
               latestModel == nil || candidate.timestamp > latestModel!.timestamp {
                latestModel = candidate
            }
            if let candidate = parsed.latestRateLimits,
               latestRateLimits == nil || candidate.timestamp > latestRateLimits!.timestamp {
                latestRateLimits = candidate
            }
        }

        // Sem uso nas últimas 24h ainda há cota a mostrar: a semanal do Codex reseta em 7 dias.
        // Aí vamos às sessões mais antigas, lendo só o fim de cada arquivo.
        if latestRateLimits == nil {
            for file in olderSessionFilesNewestFirst(excluding: recentFiles) {
                guard let candidate = CodexSessionParser.latestRateLimits(
                    at: file, tailBytes: Self.limitsTailBytes
                ) else { continue }
                if latestRateLimits == nil || candidate.timestamp > latestRateLimits!.timestamp {
                    latestRateLimits = candidate
                }
            }
        }

        // Uma janela cujo `resets_at` já passou zerou de verdade: como o rate limit que lemos é o
        // último que o Codex gravou, se ele está vencido é porque não houve NENHUM uso depois do
        // reset — ou seja, a janela nova está em 0%. Mostramos a linha em 0% (sem hora de reset:
        // a janela de 5h do Codex só começa a contar no próximo uso, então não há data a prever)
        // em vez de esconder a janela, que era o que fazia o limite de sessão desaparecer.
        let officialLimits = (latestRateLimits.map { Self.officialLimits(from: $0.limits) } ?? [])
            .map { limit -> OfficialLimitInfo in
                guard let resetsAt = limit.resetsAt, resetsAt <= now() else { return limit }
                return OfficialLimitInfo(label: limit.label, usedPercent: 0, resetsAt: nil)
            }
        let planLabel = latestRateLimits?.limits.plan_type
        let accountEmail = accountReader.read()?.email

        guard let last = UsageWindowBuilder.windows(for: allEvents).last else {
            guard !officialLimits.isEmpty else {
                return .unavailable(
                    providerId: id, displayName: displayName, isInstalled: true,
                    note: recentFiles.isEmpty
                        ? "Nenhuma sessão recente em \(sourcePath) e nenhum rate limit válido nas sessões anteriores."
                        : "Nenhum evento de token_count encontrado em \(sourcePath)"
                )
            }
            // Cota oficial válida, mas nenhuma sessão na janela de uso: mostra as barras de cota
            // sem inventar tokens.
            return ProviderSnapshot(
                providerId: id,
                displayName: displayName,
                kind: .fullTokens,
                isInstalled: true,
                windowStart: nil,
                windowEnd: nil,
                isActive: false,
                totalTokens: 0,
                totalCost: nil,
                eventCount: 0,
                byModel: [],
                officialLimits: officialLimits,
                note: "Sem sessões do Codex nas últimas 24h; mostrando os limites oficiais que ele reportou por último.",
                hourlyUsage: [],
                planLabel: planLabel,
                accountEmail: accountEmail
            )
        }

        let windowEvents = last.events
        let totalTokens = windowEvents.reduce(0) { $0 + $1.totalTokens }
        let modelName = latestModel?.model ?? "desconhecido"
        let hourlyUsage = UsageWindowBuilder.hourlyBuckets(
            for: windowEvents,
            window: last.window,
            value: \.totalTokens
        )

        return ProviderSnapshot(
            providerId: id,
            displayName: displayName,
            kind: .fullTokens,
            isInstalled: true,
            windowStart: last.window.start,
            windowEnd: last.window.end,
            isActive: last.window.isActive(),
            totalTokens: totalTokens,
            // Codex is a flat-fee subscription; we don't know the per-token price, so we never
            // invent a dollar cost for it.
            totalCost: nil,
            eventCount: windowEvents.count,
            byModel: [
                ProviderModelUsage(
                    model: modelName,
                    totalTokens: totalTokens,
                    eventCount: windowEvents.count,
                    cost: nil,
                    isEstimatedPricing: false
                )
            ],
            officialLimits: officialLimits,
            note: officialLimits.isEmpty
                ? "Nenhum rate limit oficial encontrado nas sessões locais; mostrando apenas tokens somados."
                : nil,
            hourlyUsage: hourlyUsage,
            planLabel: planLabel,
            accountEmail: accountEmail
        )
    }

    /// Sessões modificadas depois de `cutoff`. O filtro por mtime é o que evita reabrir centenas
    /// de MB de rollouts antigos a cada refresh.
    private func sessionFiles(modifiedAfter cutoff: Date) -> [URL] {
        sessionFilesWithDates().filter { $0.modified >= cutoff }.map(\.url)
    }

    /// As sessões da `limitsWindow` que NÃO estão em `recent`, da mais recente para a mais antiga
    /// e no máximo `limitsFileLimit` — candidatas a ter o último rate limit reportado.
    private func olderSessionFilesNewestFirst(excluding recent: [URL]) -> [URL] {
        let recentPaths = Set(recent.map(\.path))
        let cutoff = now().addingTimeInterval(-limitsWindow)
        return sessionFilesWithDates()
            .filter { $0.modified >= cutoff && !recentPaths.contains($0.url.path) }
            .sorted { $0.modified > $1.modified }
            .prefix(Self.limitsFileLimit)
            .map(\.url)
    }

    private func sessionFilesWithDates() -> [(url: URL, modified: Date)] {
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var files: [(url: URL, modified: Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            files.append((url, modified))
        }
        return files
    }

    /// Builds one `OfficialLimitInfo` per rate-limit window that Codex reports: `primary` (a
    /// janela mais curta e imediata, tipicamente 5h) e `secondary` (geralmente semanal). Cada uma
    /// vira uma linha própria na UI — nunca combinadas numa média.
    static func officialLimits(from limits: CodexRateLimitsPayload) -> [OfficialLimitInfo] {
        [limits.primary, limits.secondary].compactMap { window in
            guard let window else { return nil }
            let resetDate = window.resets_at.map { Date(timeIntervalSince1970: Double($0)) }
            let label = window.window_minutes.map(windowLabel(minutes:)) ?? "janela"
            return OfficialLimitInfo(
                label: label,
                usedPercent: window.used_percent ?? 0,
                resetsAt: resetDate
            )
        }
    }

    private static func windowLabel(minutes: Int) -> String {
        if minutes % (24 * 60) == 0 {
            let days = minutes / (24 * 60)
            return days == 7 ? "semanal" : "\(days)d"
        }
        if minutes % 60 == 0 {
            return "\(minutes / 60)h"
        }
        return "\(minutes)min"
    }
}
