import Foundation

/// A generic 5-hour usage window, mirroring the Claude Code 5h-block rule so every provider
/// (not just Claude Code) can report "current window / resets at" consistently.
public struct UsageWindow: Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, duration: TimeInterval = UsageWindowBuilder.windowDuration) {
        self.start = start
        self.end = start.addingTimeInterval(duration)
    }

    public func isActive(now: Date = Date()) -> Bool {
        end > now
    }

    public func remaining(now: Date = Date()) -> TimeInterval {
        max(0, end.timeIntervalSince(now))
    }
}

/// Groups any `TimestampedEvent` sequence into 5-hour windows using the same rule as
/// `FiveHourBlockBuilder` (Claude Code): a window starts at the hour floor (UTC) of its first
/// event; an event joins the current window if it's within 5h of the window's start AND within
/// 5h of the previous event, otherwise a new window opens.
public enum UsageWindowBuilder {
    public static let windowDuration: TimeInterval = 5 * 3600

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    public static func windows<T: TimestampedEvent>(for events: [T]) -> [(window: UsageWindow, events: [T])] {
        guard !events.isEmpty else { return [] }
        let sorted = events.sorted { $0.timestamp < $1.timestamp }

        var result: [(UsageWindow, [T])] = []
        var currentStart = floorToHour(sorted[0].timestamp)
        var currentEvents: [T] = [sorted[0]]
        var lastTimestamp = sorted[0].timestamp

        for event in sorted.dropFirst() {
            let sinceStart = event.timestamp.timeIntervalSince(currentStart)
            let sinceLast = event.timestamp.timeIntervalSince(lastTimestamp)

            if sinceStart < windowDuration && sinceLast < windowDuration {
                currentEvents.append(event)
                lastTimestamp = event.timestamp
            } else {
                result.append((UsageWindow(start: currentStart), currentEvents))
                currentStart = floorToHour(event.timestamp)
                currentEvents = [event]
                lastTimestamp = event.timestamp
            }
        }

        result.append((UsageWindow(start: currentStart), currentEvents))
        return result
    }

    static func floorToHour(_ date: Date) -> Date {
        let components = utcCalendar.dateComponents([.year, .month, .day, .hour], from: date)
        return utcCalendar.date(from: components) ?? date
    }
}

extension UsageWindowBuilder {
    /// Number of 1-hour slots a 5-hour window is split into for the UI's sparkline.
    public static let hourlySlotCount = 5

    /// Distributes `events` into one bucket per hour of `window`, summing whatever `value`
    /// returns for each event (tokens for token-capable providers, `1` for count-only ones).
    /// Always returns exactly `hourlySlotCount` buckets, so the UI can render a fixed-width
    /// sparkline without special-casing sparse windows.
    public static func hourlyBuckets<T: TimestampedEvent>(
        for events: [T],
        window: UsageWindow,
        value: (T) -> Int
    ) -> [Int] {
        var buckets = [Int](repeating: 0, count: hourlySlotCount)
        for event in events {
            let offset = event.timestamp.timeIntervalSince(window.start)
            guard offset >= 0 else { continue }
            let slot = min(hourlySlotCount - 1, Int(offset / 3600))
            buckets[slot] += value(event)
        }
        return buckets
    }
}
