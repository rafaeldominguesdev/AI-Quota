import Foundation

/// Reads `~/.codex/sessions/**/*.jsonl`. Despite what an earlier (wrong) pass at
/// docs/DATA-SOURCES.md said, Codex DOES report token usage locally — confirmed by inspecting
/// real session files: `event_msg` lines with `payload.type == "token_count"` carry both a
/// cumulative `total_token_usage` and a per-turn `last_token_usage`. We sum `last_token_usage`
/// deltas, never the cumulative counter (see `CodexSessionLine.swift` for why).
public struct CodexProvider: QuotaProvider {
    public let id = "codex"
    public let displayName = "Codex"
    public let kind: ProviderDataKind = .fullTokens

    private let sessionsDirectory: URL

    public init(
        sessionsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions")
    ) {
        self.sessionsDirectory = sessionsDirectory
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
        let officialLimit = latestRateLimits.flatMap { Self.officialLimit(from: $0.limits) }

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
            officialLimit: officialLimit,
            note: officialLimit == nil
                ? "Nenhum rate limit oficial encontrado nas sessões locais; mostrando apenas tokens somados."
                : nil
        )
    }

    private func findSessionFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var files: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            files.append(url)
        }
        return files
    }

    /// Builds an `OfficialLimitInfo` from Codex's `primary` rate-limit window (the shorter,
    /// more immediate one — typically 5h — vs. `secondary`, usually a weekly window).
    static func officialLimit(from limits: CodexRateLimitsPayload) -> OfficialLimitInfo? {
        guard let primary = limits.primary else { return nil }
        let resetDate = primary.resets_at.map { Date(timeIntervalSince1970: Double($0)) }
        let windowLabel = primary.window_minutes.map(windowLabel(minutes:)) ?? "janela"
        let planLabel = limits.plan_type.map { " · plano \($0)" } ?? ""
        return OfficialLimitInfo(
            label: "Codex (\(windowLabel))\(planLabel)",
            usedPercent: primary.used_percent ?? 0,
            resetsAt: resetDate
        )
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
