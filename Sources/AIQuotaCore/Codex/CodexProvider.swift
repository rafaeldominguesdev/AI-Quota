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
    private let now: @Sendable () -> Date

    /// `id`/`displayName` têm outro valor só para uma segunda (terceira...) conta descoberta por
    /// `MultiAccountDiscovery` — a conta padrão continua "codex"/"Codex".
    ///
    /// `recentWindow` (padrão 24h): só o rate limit e a janela de uso mais recentes importam
    /// aqui, então arquivos de sessão não tocados há mais tempo que isso nem são abertos — sem
    /// isto, cada refresh de 30s reprocessava centenas de MB de sessões antigas à toa.
    public init(
        sessionsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions"),
        accountReader: CodexAccountReader = CodexAccountReader(),
        id: String = "codex",
        displayName: String = "Codex",
        recentWindow: TimeInterval = 24 * 3600,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.sessionsDirectory = sessionsDirectory
        self.accountReader = accountReader
        self.id = id
        self.displayName = displayName
        self.recentWindow = recentWindow
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

        let files = findSessionFiles()
        guard !files.isEmpty else {
            return .unavailable(
                providerId: id, displayName: displayName, isInstalled: true,
                note: "Nenhuma sessão encontrada em \(sourcePath)"
            )
        }

        var allEvents: [CodexTokenEvent] = []
        var latestModel: (timestamp: Date, model: String)?
        var latestRateLimits: (timestamp: Date, limits: CodexRateLimitsPayload)?

        for file in files {
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

        guard let last = UsageWindowBuilder.windows(for: allEvents).last else {
            return .unavailable(
                providerId: id, displayName: displayName, isInstalled: true,
                note: "Nenhum evento de token_count encontrado em \(sourcePath)"
            )
        }

        let windowEvents = last.events
        let totalTokens = windowEvents.reduce(0) { $0 + $1.totalTokens }
        let modelName = latestModel?.model ?? "desconhecido"
        let officialLimits = latestRateLimits.map { Self.officialLimits(from: $0.limits) } ?? []
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
            planLabel: latestRateLimits?.limits.plan_type,
            accountEmail: accountReader.read()?.email
        )
    }

    private func findSessionFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        let cutoff = now().addingTimeInterval(-recentWindow)
        var files: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if let modified, modified < cutoff { continue }
            files.append(url)
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
