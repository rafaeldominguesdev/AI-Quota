import Foundation

/// Anything with a timestamp that can be grouped into usage windows by `UsageWindowBuilder`.
public protocol TimestampedEvent {
    var timestamp: Date { get }
}

extension UsageEvent: TimestampedEvent {}
extension CursorUsageRecord: TimestampedEvent {}
