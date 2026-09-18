import Foundation

struct CustomLogEvent: TimestampedEvent {
    let timestamp: Date
    let model: String?
    let inputTokens: Int?
    let outputTokens: Int?
    let totalTokens: Int?
}

/// A generic JSONL-log provider entirely described by a `CustomLogProviderConfig` — this is what
/// lets someone add GLM, Qwen, DeepSeek, or any other CLI by editing `providers.json`, with no
/// Swift code and no recompilation.
public struct CustomLogProvider: QuotaProvider {
    public let id: String
    public let displayName: String

    private let config: CustomLogProviderConfig

    public init(config: CustomLogProviderConfig) {
        self.id = config.id
        self.displayName = config.displayName
        self.config = config
    }

    public var sourcePath: String { config.logGlob }

    public var kind: ProviderDataKind {
        if config.inputTokensPath != nil && config.outputTokensPath != nil { return .fullTokens }
        if config.totalTokensPath != nil { return .tokensOnly }
        return .countOnly
    }

    public var isInstalled: Bool {
        !GlobResolver.resolve(config.logGlob).isEmpty
    }

    public func snapshot(config providerConfig: QuotaConfig) throws -> ProviderSnapshot {
        let files = GlobResolver.resolve(config.logGlob)
        guard !files.isEmpty else {
            return .unavailable(
                providerId: id, displayName: displayName, isInstalled: false,
                note: "Nenhum arquivo encontrado em \(config.logGlob)"
            )
        }

        var allEvents: [CustomLogEvent] = []
        for file in files {
            allEvents.append(contentsOf: parseFile(at: file))
        }

        guard let last = UsageWindowBuilder.windows(for: allEvents).last else {
            return .unavailable(
                providerId: id, displayName: displayName, kind: kind, isInstalled: true,
                note: "Nenhum evento decodificado em \(config.logGlob) (confira os caminhos configurados em providers.json)"
            )
        }

        let windowEvents = last.events
        let resolvedKind = kind

        let byModelGroups = Dictionary(grouping: windowEvents, by: { $0.model ?? "desconhecido" })
        let byModel = byModelGroups.map { model, events -> ProviderModelUsage in
            let totalTokens = totalTokens(for: events, kind: resolvedKind)
            let cost = cost(for: events, kind: resolvedKind)
            return ProviderModelUsage(model: model, totalTokens: totalTokens, eventCount: events.count, cost: cost, isEstimatedPricing: false)
        }.sorted { $0.totalTokens > $1.totalTokens }

        let totalTokensSum = byModel.reduce(0) { $0 + $1.totalTokens }
        let totalCostSum: Double? = config.pricing == nil ? nil : byModel.reduce(0) { $0 + ($1.cost ?? 0) }

        let hourlyUsage = UsageWindowBuilder.hourlyBuckets(for: windowEvents, window: last.window) { event in
            switch resolvedKind {
            case .fullTokens: return (event.inputTokens ?? 0) + (event.outputTokens ?? 0)
            case .tokensOnly: return event.totalTokens ?? 0
            case .countOnly, .unavailable: return 1
            }
        }

        return ProviderSnapshot(
            providerId: id,
            displayName: displayName,
            kind: resolvedKind,
            isInstalled: true,
            windowStart: last.window.start,
            windowEnd: last.window.end,
            isActive: last.window.isActive(),
            totalTokens: totalTokensSum,
            totalCost: totalCostSum,
            eventCount: windowEvents.count,
            byModel: byModel,
            note: resolvedKind == .countOnly ? "Sem dado de token configurado em providers.json — só contando eventos." : nil,
            hourlyUsage: hourlyUsage
        )
    }

    private func totalTokens(for events: [CustomLogEvent], kind: ProviderDataKind) -> Int {
        switch kind {
        case .fullTokens:
            return events.reduce(0) { $0 + ($1.inputTokens ?? 0) + ($1.outputTokens ?? 0) }
        case .tokensOnly:
            return events.reduce(0) { $0 + ($1.totalTokens ?? 0) }
        case .countOnly, .unavailable:
            return 0
        }
    }

    private func cost(for events: [CustomLogEvent], kind: ProviderDataKind) -> Double? {
        guard kind == .fullTokens, let pricing = config.pricing else { return nil }
        let inputSum = events.reduce(0) { $0 + ($1.inputTokens ?? 0) }
        let outputSum = events.reduce(0) { $0 + ($1.outputTokens ?? 0) }
        return Double(inputSum) * pricing.inputPer1M / 1_000_000 + Double(outputSum) * pricing.outputPer1M / 1_000_000
    }

    // MARK: - Parsing

    private func parseFile(at url: URL) -> [CustomLogEvent] {
        guard let reader = FileLineReader(path: url.path) else { return [] }
        defer { reader.close() }

        var raw: [(timestamp: Date, model: String?, input: Int?, output: Int?, total: Int?)] = []
        while let line = reader.nextLine() {
            guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
            guard let json = try? JSONSerialization.jsonObject(with: data) else { continue }

            guard let timestamp = Self.resolveTimestamp(path: config.timestampPath, in: json) else { continue }
            let model = config.modelPath.flatMap { JSONPathResolver.string(at: $0, in: json) }
            let input = config.inputTokensPath.flatMap { JSONPathResolver.int(at: $0, in: json) }
            let output = config.outputTokensPath.flatMap { JSONPathResolver.int(at: $0, in: json) }
            let total = config.totalTokensPath.flatMap { JSONPathResolver.int(at: $0, in: json) }

            raw.append((timestamp, model, input, output, total))
        }

        return config.cumulative ? Self.deltas(from: raw) : raw.map {
            CustomLogEvent(timestamp: $0.timestamp, model: $0.model, inputTokens: $0.input, outputTokens: $0.output, totalTokens: $0.total)
        }
    }

    /// Resolves a JSON value at `path` as an ISO 8601 string or a Unix-epoch number (seconds or
    /// milliseconds, guessed from magnitude), since custom log formats could use either.
    static func resolveTimestamp(path: String, in json: Any) -> Date? {
        if let string = JSONPathResolver.string(at: path, in: json), let date = ISO8601Parsing.date(from: string) {
            return date
        }
        if let number = JSONPathResolver.double(at: path, in: json) {
            // Anything above ~year-2001-in-seconds is almost certainly milliseconds.
            let seconds = number > 20_000_000_000 ? number / 1000 : number
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }

    /// Turns running-total counters (one session's worth, in file order) into per-event deltas —
    /// the same idea as Codex's `total_token_usage`, generalized for any cumulative custom log.
    /// A counter that drops below its previous value is treated as a fresh run (delta = the
    /// value itself), never as a negative delta.
    static func deltas(
        from raw: [(timestamp: Date, model: String?, input: Int?, output: Int?, total: Int?)]
    ) -> [CustomLogEvent] {
        var lastInput = 0
        var lastOutput = 0
        var lastTotal = 0
        var result: [CustomLogEvent] = []

        for entry in raw {
            var deltaInput: Int?
            var deltaOutput: Int?
            var deltaTotal: Int?

            if let input = entry.input {
                deltaInput = max(0, input - lastInput)
                lastInput = input
            }
            if let output = entry.output {
                deltaOutput = max(0, output - lastOutput)
                lastOutput = output
            }
            if let total = entry.total {
                deltaTotal = max(0, total - lastTotal)
                lastTotal = total
            }

            result.append(CustomLogEvent(timestamp: entry.timestamp, model: entry.model, inputTokens: deltaInput, outputTokens: deltaOutput, totalTokens: deltaTotal))
        }

        return result
    }
}
