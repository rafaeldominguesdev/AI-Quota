import Foundation

/// Um bloco de faturamento de 5 horas do Claude Code.
public struct FiveHourBlock: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let events: [UsageEvent]

    public init(start: Date, events: [UsageEvent]) {
        self.start = start
        self.end = start.addingTimeInterval(FiveHourBlockBuilder.blockDuration)
        self.events = events
    }

    /// Ativo quando o fim do bloco ainda está no futuro em relação a `now`.
    /// Pela forma como os blocos são construídos (ver `FiveHourBlockBuilder`), no máximo
    /// o último bloco da lista pode satisfazer essa condição.
    public func isActive(now: Date = Date()) -> Bool {
        end > now
    }

    public func remaining(now: Date = Date()) -> TimeInterval {
        max(0, end.timeIntervalSince(now))
    }

    public var totalTokens: Int {
        events.reduce(0) { $0 + $1.totalTokens }
    }

    public var totalCost: Double {
        CostCalculator.totalCost(for: events)
    }

    public var eventsByModel: [String: [UsageEvent]] {
        Dictionary(grouping: events, by: { $0.model })
    }
}

public enum FiveHourBlockBuilder {
    public static let blockDuration: TimeInterval = 5 * 3600

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Agrupa eventos (não precisam estar ordenados) em blocos de 5 horas.
    ///
    /// Regra:
    /// - Os eventos são ordenados por timestamp.
    /// - O primeiro evento de um bloco abre o bloco com início arredondado para baixo
    ///   na hora cheia (UTC).
    /// - Um evento entra no bloco atual se estiver a menos de 5h do início do bloco
    ///   E a menos de 5h do evento anterior. Caso contrário, abre um novo bloco.
    public static func buildBlocks(from events: [UsageEvent]) -> [FiveHourBlock] {
        guard !events.isEmpty else { return [] }
        let sorted = events.sorted { $0.timestamp < $1.timestamp }

        var blocks: [FiveHourBlock] = []
        var currentStart = floorToHour(sorted[0].timestamp)
        var currentEvents: [UsageEvent] = [sorted[0]]
        var lastTimestamp = sorted[0].timestamp

        for event in sorted.dropFirst() {
            let sinceStart = event.timestamp.timeIntervalSince(currentStart)
            let sinceLast = event.timestamp.timeIntervalSince(lastTimestamp)

            if sinceStart < blockDuration && sinceLast < blockDuration {
                currentEvents.append(event)
                lastTimestamp = event.timestamp
            } else {
                blocks.append(FiveHourBlock(start: currentStart, events: currentEvents))
                currentStart = floorToHour(event.timestamp)
                currentEvents = [event]
                lastTimestamp = event.timestamp
            }
        }

        blocks.append(FiveHourBlock(start: currentStart, events: currentEvents))
        return blocks
    }

    /// Arredonda um timestamp para baixo na hora cheia, em UTC.
    static func floorToHour(_ date: Date) -> Date {
        let components = utcCalendar.dateComponents([.year, .month, .day, .hour], from: date)
        return utcCalendar.date(from: components) ?? date
    }
}
