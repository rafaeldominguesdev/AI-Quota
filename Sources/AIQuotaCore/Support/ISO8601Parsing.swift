import Foundation

/// Shared ISO 8601 parsing for the log formats used across providers (all of them use
/// `"2026-09-17T16:39:27.573Z"`-style timestamps, with or without fractional seconds).
enum ISO8601Parsing {
    private static let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let withoutFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: false)

    static func date(from string: String) -> Date? {
        (try? withFraction.parse(string)) ?? (try? withoutFraction.parse(string))
    }
}
