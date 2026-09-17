import Foundation

/// A single Codex turn's token usage, already extracted as a per-event delta (never a running
/// cumulative total — see `CodexSessionLine.swift`).
public struct CodexTokenEvent: Equatable, Sendable, TimestampedEvent {
    public let timestamp: Date
    public let inputTokens: Int
    public let cachedInputTokens: Int
    public let cacheWriteInputTokens: Int
    public let outputTokens: Int
    public let reasoningOutputTokens: Int
    public let totalTokens: Int
}

/// One session file's parsed contents.
struct CodexParsedSession {
    var events: [CodexTokenEvent] = []
    var latestModel: (timestamp: Date, model: String)?
    var latestRateLimits: (timestamp: Date, limits: CodexRateLimitsPayload)?
}
