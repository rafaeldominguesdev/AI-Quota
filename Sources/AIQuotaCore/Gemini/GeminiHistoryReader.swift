import Foundation

/// One interaction recorded in `~/.gemini/antigravity-cli/history.jsonl`. Confirmed by grepping
/// the whole `~/.gemini` tree for token-usage field names (`totalTokenCount`, `promptTokenCount`,
/// `usageMetadata`) — none exist. This history file only has `display`/`timestamp`/`workspace`/
/// `type`, so all we can do is count interactions, never tokens.
struct GeminiHistoryEvent: TimestampedEvent {
    let timestamp: Date
}

enum GeminiHistoryReader {
    private struct Line: Decodable {
        /// Unix milliseconds.
        let timestamp: Double?
    }

    private static let decoder = JSONDecoder()

    static func parseFile(at url: URL) -> [GeminiHistoryEvent] {
        guard let reader = FileLineReader(path: url.path) else { return [] }
        defer { reader.close() }

        var events: [GeminiHistoryEvent] = []
        while let line = reader.nextLine() {
            guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
            guard let decoded = try? decoder.decode(Line.self, from: data), let ms = decoded.timestamp else { continue }
            events.append(GeminiHistoryEvent(timestamp: Date(timeIntervalSince1970: ms / 1000)))
        }
        return events
    }
}
