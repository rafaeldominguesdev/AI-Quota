import Foundation
@testable import AIQuotaCore

func makeEvent(
    timestamp: Date = utcDate(2026, 1, 1, 0),
    model: String = "claude-sonnet-5",
    sessionId: String = "sessao-teste",
    messageId: String? = "msg_1",
    requestId: String? = "req_1",
    inputTokens: Int = 100,
    outputTokens: Int = 50,
    cacheCreationInputTokens: Int = 0,
    cacheReadInputTokens: Int = 0,
    thinkingTokens: Int = 0,
    cacheCreation5mTokens: Int = 0,
    cacheCreation1hTokens: Int = 0
) -> UsageEvent {
    UsageEvent(
        timestamp: timestamp,
        model: model,
        sessionId: sessionId,
        messageId: messageId,
        requestId: requestId,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        cacheCreationInputTokens: cacheCreationInputTokens,
        cacheReadInputTokens: cacheReadInputTokens,
        thinkingTokens: thinkingTokens,
        cacheCreation5mTokens: cacheCreation5mTokens,
        cacheCreation1hTokens: cacheCreation1hTokens
    )
}

func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
    return calendar.date(from: components)!
}
