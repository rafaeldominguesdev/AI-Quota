import Foundation

/// Parses `~/.codex/sessions/**/*.jsonl` rollout files.
enum CodexSessionParser {
    private static let decoder = JSONDecoder()

    /// Streams a whole session file line by line (never loads it fully into memory) and
    /// extracts token usage deltas, the active model, and the most recent populated rate limits.
    static func parseFile(at url: URL) -> CodexParsedSession {
        guard let reader = FileLineReader(path: url.path) else { return CodexParsedSession() }
        defer { reader.close() }

        var session = CodexParsedSession()
        while let line = reader.nextLine() {
            guard !line.isEmpty else { continue }

            if let event = decodeTokenEvent(fromLine: line) {
                session.events.append(event)
            }
            if let (timestamp, model) = decodeModel(fromLine: line) {
                if session.latestModel == nil || timestamp > session.latestModel!.timestamp {
                    session.latestModel = (timestamp, model)
                }
            }
            if let (timestamp, limits) = decodeRateLimits(fromLine: line) {
                if session.latestRateLimits == nil || timestamp > session.latestRateLimits!.timestamp {
                    session.latestRateLimits = (timestamp, limits)
                }
            }
        }
        return session
    }

    /// Lê SÓ o fim do arquivo (últimos `tailBytes`) procurando o rate limit mais recente que ele
    /// gravou. Serve para sessões antigas/gigantes (há rollouts de 70+ MB no disco): a cota
    /// semanal do Codex continua valendo dias depois do último uso, então precisamos desse dado
    /// mesmo de um arquivo que não vale a pena varrer inteiro a cada refresh.
    static func latestRateLimits(at url: URL, tailBytes: Int) -> (timestamp: Date, limits: CodexRateLimitsPayload)? {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let offset = UInt64(max(0, size - tailBytes))
        guard let reader = FileLineReader(path: url.path, startingAtOffset: offset) else { return nil }
        defer { reader.close() }

        // A primeira linha depois de um salto começa no meio de um JSON — descarta.
        if offset > 0 { _ = reader.nextLine() }

        var latest: (timestamp: Date, limits: CodexRateLimitsPayload)?
        while let line = reader.nextLine() {
            guard !line.isEmpty else { continue }
            if let (timestamp, limits) = decodeRateLimits(fromLine: line),
               latest == nil || timestamp > latest!.timestamp {
                latest = (timestamp, limits)
            }
        }
        return latest
    }

    /// Decodes an `event_msg` / `token_count` line into a per-turn usage delta, taken from
    /// `last_token_usage` (never `total_token_usage` — see `CodexSessionLine.swift`).
    static func decodeTokenEvent(fromLine line: String) -> CodexTokenEvent? {
        guard let parsed = decodeLine(line) else { return nil }
        guard parsed.type == "event_msg", parsed.payload?.type == "token_count" else { return nil }
        guard let timestampString = parsed.timestamp, let timestamp = ISO8601Parsing.date(from: timestampString) else { return nil }
        guard let usage = parsed.payload?.info?.last_token_usage else { return nil }

        return CodexTokenEvent(
            timestamp: timestamp,
            inputTokens: usage.input_tokens ?? 0,
            cachedInputTokens: usage.cached_input_tokens ?? 0,
            cacheWriteInputTokens: usage.cache_write_input_tokens ?? 0,
            outputTokens: usage.output_tokens ?? 0,
            reasoningOutputTokens: usage.reasoning_output_tokens ?? 0,
            totalTokens: usage.total_tokens ?? 0
        )
    }

    /// Decodes a `turn_context` line's model, when present.
    static func decodeModel(fromLine line: String) -> (timestamp: Date, model: String)? {
        guard let parsed = decodeLine(line) else { return nil }
        guard parsed.type == "turn_context", let model = parsed.payload?.model else { return nil }
        guard let timestampString = parsed.timestamp, let timestamp = ISO8601Parsing.date(from: timestampString) else { return nil }
        return (timestamp, model)
    }

    /// Decodes a `token_count` line's `rate_limits`, when its `primary` window is populated
    /// (most events have `rate_limits` entirely null, or with `primary`/`secondary` both null).
    static func decodeRateLimits(fromLine line: String) -> (timestamp: Date, limits: CodexRateLimitsPayload)? {
        guard let parsed = decodeLine(line) else { return nil }
        guard parsed.type == "event_msg", parsed.payload?.type == "token_count" else { return nil }
        guard let limits = parsed.payload?.rate_limits, limits.primary != nil || limits.secondary != nil else { return nil }
        guard let timestampString = parsed.timestamp, let timestamp = ISO8601Parsing.date(from: timestampString) else { return nil }
        return (timestamp, limits)
    }

    private static func decodeLine(_ line: String) -> CodexSessionLine? {
        guard let data = line.data(using: .utf8) else { return nil }
        return try? decoder.decode(CodexSessionLine.self, from: data)
    }
}
