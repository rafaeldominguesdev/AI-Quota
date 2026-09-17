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
